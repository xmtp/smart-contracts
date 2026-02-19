// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../../Deploy.s.sol";
import { PayerReportManagerDeployer } from "../../deployers/PayerReportManagerDeployer.sol";
import { Utils } from "../../utils/Utils.sol";
import { AdminAddressTypeLib } from "../../utils/AdminAddressType.sol";
import {
    ISettlementChainParameterRegistry
} from "../../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";
import { IPayerRegistry } from "../../../src/settlement-chain/interfaces/IPayerRegistry.sol";

/**
 * @title DeployPayerReportManagerScript
 * @notice Deploys a new PayerReportManager proxy and implementation pair.
 * @dev See DeployPayerReportManager.md for detailed deployment instructions.
 *      Entry points: predictAddresses(), deployContract(), SetParameterRegistryValues(),
 *      UpdateContractDependencies().
 */
contract DeployPayerReportManagerScript is DeployScripts {
    error EnvironmentContainsPayerReportManager();
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

    /// @notice Step 2: Deploy PayerReportManager implementation and proxy.
    /// @dev Outputs FIREBLOCKS_NOTE for Step 3a if using Fireblocks.
    function deployContract() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        console.log("Deploying PayerReportManager");

        // Validate config address matches deterministic address before attempting deployment
        _validateImplementationAddress();

        // Deploy implementation first
        deployPayerReportManagerImplementation();

        // Deploy proxy (automatically initializes and configures proxy to point at implementation)
        deployPayerReportManagerProxy();

        // Update environment JSON with payerReportManager address
        _writePayerReportManagerToEnvironment();

        console.log("PayerReportManager deployment complete");

        // Output Fireblocks values for Step 3a (if using Fireblocks)
        console.log("==========================================");
        console.log("If using Fireblocks for Step 3a, export these values:");
        console.log('  export FIREBLOCKS_NOTE="Deploy PayerReportManager - set settler parameter"');
        console.log("  export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)");
        console.log("==========================================");
    }

    /**
     * @notice Step 3a (set values): Set xmtp.payerRegistry.settler in the parameter registry (requires ADMIN).
     * @dev Sets the settler address to the newly deployed PayerReportManager proxy.
     *      This is an admin-only operation that requires Fireblocks signing in production environments.
     */
    function SetParameterRegistryValues() external {
        _initializeAdmin();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        console.log("Setting PayerReportManager parameters in parameter registry");

        // Read the PayerReportManager proxy address from the environment JSON file
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        string memory json_ = vm.readFile(filePath_);
        address payerReportManagerProxy_ = vm.parseJsonAddress(json_, ".payerReportManager");
        if (payerReportManagerProxy_ == address(0)) {
            revert("PayerReportManager proxy address not found in environment JSON");
        }
        console.log("PayerReportManager proxy address from environment:", payerReportManagerProxy_);

        // Update SettlementChainParameterRegistry key xmtp.payerRegistry.settler
        string memory settlerKey_ = "xmtp.payerRegistry.settler";
        bytes32 settlerValue_ = bytes32(uint256(uint160(payerReportManagerProxy_)));
        console.log("Setting SettlementChainParameterRegistry parameter:");
        console.log("  Key: %s", settlerKey_);
        console.log("  Value (PayerReportManager proxy): %s", payerReportManagerProxy_);

        // Set parameter in parameter registry (using ADMIN)
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(settlerKey_, settlerValue_);
        vm.stopBroadcast();

        console.log("Successfully set SettlementChainParameterRegistry parameter");
    }

    /**
     * @notice Step 3a (pull values): Update PayerRegistry by calling updateSettler() (permissionless, uses DEPLOYER).
     * @dev Calls PayerRegistry.updateSettler() which is a permissionless function
     *      that reads from the parameter registry and updates local contract state.
     */
    function UpdateContractDependencies() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        console.log("Updating PayerReportManager contract dependencies");

        // Call PayerRegistry.updateSettler() (using DEPLOYER)
        console.log("Calling PayerRegistry.updateSettler()");
        console.log("  PayerRegistry proxy: %s", _deploymentData.payerRegistryProxy);

        vm.startBroadcast(_deployerPrivateKey);
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateSettler();
        vm.stopBroadcast();

        console.log("Successfully called PayerRegistry.updateSettler()");
        console.log("PayerReportManager dependencies update complete");
    }

    /// @notice Step 1: Predict deterministic addresses for implementation and proxy.
    function predictAddresses() external view {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.payerReportManagerProxySalt == 0) revert ProxySaltNotSet();

        address computedImplementation_ = PayerReportManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerRegistryProxy
        );

        address computedProxy_ = PayerReportManagerDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.payerReportManagerProxySalt
        );

        console.log("Proxy Salt:", Utils.bytes32ToString(_deploymentData.payerReportManagerProxySalt));
        console.log("PayerReportManager Predicted Addresses:");
        console.log("  Implementation:", computedImplementation_);
        console.log("  Proxy:", computedProxy_);
        if (_deploymentData.payerReportManagerProxy != address(0)) {
            if (computedProxy_ == _deploymentData.payerReportManagerProxy) {
                console.log("Predicted proxy matches payerReportManagerProxy in config JSON.");
            } else {
                console.log("WARNING: Predicted proxy does NOT match payerReportManagerProxy in config JSON!");
                console.log("  Config JSON value:", _deploymentData.payerReportManagerProxy);
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

    function _ensureNoPayerReportManager(string memory json_) internal view {
        // Copying the intent from Deploy.s.sol. Environment JSON must have any existing payer report manager value
        // manually removed before starting.
        if (vm.keyExists(json_, ".payerReportManager")) {
            revert EnvironmentContainsPayerReportManager();
        }
    }

    function _validateImplementationAddress() internal view {
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        // Compute the deterministic address that will be deployed
        address computedImplementation_ = PayerReportManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerRegistryProxy
        );

        // Validate config address matches deterministic address before attempting deployment
        if (_deploymentData.payerReportManagerImplementation != computedImplementation_) {
            revert ImplementationAddressMismatch(
                _deploymentData.payerReportManagerImplementation,
                computedImplementation_
            );
        }
    }

    function _writePayerReportManagerToEnvironment() internal {
        _prepareEnvironmentJson(_ensureNoPayerReportManager);

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        vm.serializeJson("root", vm.readFile(filePath_));
        string memory json_ = vm.serializeAddress(
            "root",
            "payerReportManager",
            _deploymentData.payerReportManagerProxy
        );

        // Only update the environment JSON if broadcasting
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            vm.writeJson(json_, filePath_);
        } else {
            console.log("Not broadcasted. No writes to environment JSON.");
        }
    }
}
