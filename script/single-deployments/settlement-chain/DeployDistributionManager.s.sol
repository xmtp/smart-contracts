// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../../Deploy.s.sol";
import { DistributionManagerDeployer } from "../../deployers/DistributionManagerDeployer.sol";
import { Utils } from "../../utils/Utils.sol";
import { AdminAddressTypeLib } from "../../utils/AdminAddressType.sol";
import {
    ISettlementChainParameterRegistry
} from "../../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";
import { IPayerRegistry } from "../../../src/settlement-chain/interfaces/IPayerRegistry.sol";

/**
 * @title DeployDistributionManagerScript
 * @notice Deploys a new DistributionManager proxy and implementation pair.
 * @dev See DeployDistributionManager.md for detailed deployment instructions.
 *      Entry points: predictAddresses(), deployContract(), SetParameterRegistryValues(),
 *      UpdateContractDependencies().
 */
contract DeployDistributionManagerScript is DeployScripts {
    error EnvironmentContainsDistributionManager();
    error ImplementationAddressMismatch(address expected, address computed);
    error AdminNotSet();

    uint256 internal _adminPrivateKey;
    address internal _admin;
    AdminAddressTypeLib.AdminAddressType internal _adminAddressType;

    /**
     * @dev Initializes admin-related variables. Called at the start of functions that need admin access.
     *      The parent DeployScripts.setUp() already initializes _environment, _deployer, and _deployerPrivateKey.
     */
    function _initializeAdmin() internal {
        // Determine admin address type based on environment with optional override
        _adminAddressType = AdminAddressTypeLib.getAdminAddressType(_environment);

        // Admin setup (for setting parameters in parameter registry)
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            _adminPrivateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
            if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
            _admin = vm.addr(_adminPrivateKey);
            console.log("Admin (Wallet): %s", _admin);
        } else {
            _admin = vm.envAddress("ADMIN");
            if (_admin == address(0)) revert AdminNotSet();
            console.log("Admin (Fireblocks): %s", _admin);
        }
    }

    /// @notice Step 2: Deploy DistributionManager implementation and proxy.
    function deployContract() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        console.log("Deploying DistributionManager");

        // Validate config address matches deterministic address before attempting deployment
        _validateImplementationAddress();

        // Deploy implementation first
        deployDistributionManagerImplementation();

        // Deploy proxy (automatically initializes and configures proxy to point at implementation)
        deployDistributionManagerProxy();

        // Update environment JSON with distributionManager address
        _writeDistributionManagerToEnvironment();

        console.log("DistributionManager deployment complete");
    }

    /**
     * @notice Step 3a (set values): Set xmtp.payerRegistry.feeDistributor in the parameter registry (requires ADMIN).
     * @dev Sets the feeDistributor address to the newly deployed DistributionManager proxy.
     *      This is an admin-only operation that requires Fireblocks signing in production environments.
     */
    function SetParameterRegistryValues() external {
        _initializeAdmin();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        console.log("Setting DistributionManager parameters in parameter registry");

        // Read the DistributionManager proxy address from the environment JSON file
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        string memory json_ = vm.readFile(filePath_);
        address distributionManagerProxy_ = vm.parseJsonAddress(json_, ".distributionManager");
        if (distributionManagerProxy_ == address(0)) {
            revert("DistributionManager proxy address not found in environment JSON");
        }
        console.log("DistributionManager proxy address from environment:", distributionManagerProxy_);

        // Update SettlementChainParameterRegistry key xmtp.payerRegistry.feeDistributor
        string memory feeDistributorKey_ = "xmtp.payerRegistry.feeDistributor";
        bytes32 feeDistributorValue_ = bytes32(uint256(uint160(distributionManagerProxy_)));
        console.log("Setting SettlementChainParameterRegistry parameter:");
        console.log("  Key: %s", feeDistributorKey_);
        console.log("  Value (DistributionManager proxy): %s", distributionManagerProxy_);

        // Set parameter in parameter registry (using ADMIN)
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(
            feeDistributorKey_,
            feeDistributorValue_
        );
        vm.stopBroadcast();

        console.log("Successfully set SettlementChainParameterRegistry parameter");
    }

    /**
     * @notice Step 3a (pull values): Update PayerRegistry by calling updateFeeDistributor() (permissionless, uses DEPLOYER).
     * @dev Calls PayerRegistry.updateFeeDistributor() which is a permissionless function
     *      that reads from the parameter registry and updates local contract state.
     */
    function UpdateContractDependencies() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        console.log("Updating DistributionManager contract dependencies");

        // Call PayerRegistry.updateFeeDistributor() (using DEPLOYER)
        console.log("Calling PayerRegistry.updateFeeDistributor()");
        console.log("  PayerRegistry proxy: %s", _deploymentData.payerRegistryProxy);

        vm.startBroadcast(_deployerPrivateKey);
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateFeeDistributor();
        vm.stopBroadcast();

        console.log("Successfully called PayerRegistry.updateFeeDistributor()");
        console.log("DistributionManager dependencies update complete");
    }

    /// @notice Step 1: Predict deterministic addresses for implementation and proxy.
    function predictAddresses() external view {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerReportManagerProxy == address(0)) revert PayerReportManagerProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();
        if (_deploymentData.distributionManagerProxySalt == 0) revert ProxySaltNotSet();

        address computedImplementation_ = DistributionManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerReportManagerProxy,
            _deploymentData.payerRegistryProxy,
            _deploymentData.feeTokenProxy
        );

        address computedProxy_ = DistributionManagerDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.distributionManagerProxySalt
        );

        console.log("Proxy Salt:", Utils.bytes32ToString(_deploymentData.distributionManagerProxySalt));
        console.log("DistributionManager Predicted Addresses:");
        console.log("  Implementation:", computedImplementation_);
        console.log("  Proxy:", computedProxy_);
        if (_deploymentData.distributionManagerProxy != address(0)) {
            if (computedProxy_ == _deploymentData.distributionManagerProxy) {
                console.log("Predicted proxy matches distributionManagerProxy in config JSON.");
            } else {
                console.log("WARNING: Predicted proxy does NOT match distributionManagerProxy in config JSON!");
                console.log("  Config JSON value:", _deploymentData.distributionManagerProxy);
            }
        }

        // Check if code already exists at predicted addresses
        if (computedImplementation_.code.length > 0) {
            console.log("WARNING: Code already exists at predicted implementation address!");
        }
        if (computedProxy_.code.length > 0) {
            console.log("WARNING: Code already exists at predicted proxy address!");
        }
    }

    function _ensureNoDistributionManager(string memory json_) internal view {
        // Copying the intent from Deploy.s.sol. Environment JSON must have any existing distribution manager value
        // manually removed before starting.
        if (vm.keyExists(json_, ".distributionManager")) {
            revert EnvironmentContainsDistributionManager();
        }
    }

    function _validateImplementationAddress() internal view {
        if (_deploymentData.distributionManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerReportManagerProxy == address(0)) revert PayerReportManagerProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();

        // Compute the deterministic address that will be deployed
        address computedImplementation_ = DistributionManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerReportManagerProxy,
            _deploymentData.payerRegistryProxy,
            _deploymentData.feeTokenProxy
        );

        // Validate config address matches deterministic address before attempting deployment
        if (_deploymentData.distributionManagerImplementation != computedImplementation_) {
            revert ImplementationAddressMismatch(
                _deploymentData.distributionManagerImplementation,
                computedImplementation_
            );
        }
    }

    function _writeDistributionManagerToEnvironment() internal {
        _prepareEnvironmentJson(_ensureNoDistributionManager);

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        vm.serializeJson("root", vm.readFile(filePath_));
        string memory json_ = vm.serializeAddress(
            "root",
            "distributionManager",
            _deploymentData.distributionManagerProxy
        );

        // Only update the environment JSON if broadcasting
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            vm.writeJson(json_, filePath_);
        } else {
            console.log("Not broadcasted. No writes to environment JSON.");
        }
    }
}
