// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../../Deploy.s.sol";
import { DistributionManagerDeployer } from "../../deployers/DistributionManagerDeployer.sol";
import { Utils } from "../../utils/Utils.sol";
import {
    ISettlementChainParameterRegistry
} from "../../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";
import { IPayerRegistry } from "../../../src/settlement-chain/interfaces/IPayerRegistry.sol";

/**
 * @title DeployDistributionManagerScript
 * @notice Script to deploy a fresh release of the DistributionManager contract (proxy and implementation pair)
 * @dev This script inherits from Deploy.s.sol, and has three entry points:
 * 1) deployContract() to deploy a new DistributionManager contract (proxy and implementation pair)
 * Calls into mass deploy script Deploy.s.sol for a single deployment of DistributionManager:
 * - Validates the proxy & implementation addresses match the deterministic address held in config JSON.
 * - Deploys the implementation & proxy (no-ops if already present on chain as was requested).
 * - Updates the environment JSON with the new distributionManager proxy address.
 * Usage: ENVIRONMENT=testnet-dev forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
 *
 * 2) updateDependencies() to update the dependencies of the DistributionManager contract
 * - Updates the SettlementChainParameterRegistry key xmtp.payerRegistry.feeDistributor with the new DistributionManager proxy address
 * - Calls PayerRegistry.updateFeeDistributor() to update the fee distributor in the PayerRegistry contract
 * Usage: ENVIRONMENT=testnet-dev forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "updateDependencies()" --broadcast
 *
 * 3) predictAddresses() to print the predicted addresses of the implementation & proxy (a helper function, doesn't broadcast)
 * The proxy address depends on the factory addresss, deployer address and the salt.
 * The implementation address depends on the factory address and the implementation bytecode.
 * Usage: ENVIRONMENT=testnet-dev forge script DeployDistributionManagerScript --rpc-url base_sepolia --sig "predictAddresses()"
 */
contract DeployDistributionManagerScript is DeployScripts {
    error EnvironmentContainsDistributionManager();
    error ImplementationAddressMismatch(address expected, address computed);

    uint256 internal _adminPrivateKey;

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

    function updateDependencies() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        // Load admin private key from environment variable
        _adminPrivateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
        if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
        address admin_ = vm.addr(_adminPrivateKey);
        console.log("Admin: %s", admin_);
        console.log("Updating DistributionManager dependencies");

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
        console.log("Updating SettlementChainParameterRegistry parameter:");
        console.log("  Key: %s", feeDistributorKey_);
        console.log("  Value (DistributionManager proxy): %s", distributionManagerProxy_);

        vm.startBroadcast(_adminPrivateKey);
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(
            feeDistributorKey_,
            feeDistributorValue_
        );
        vm.stopBroadcast();

        console.log("Successfully updated SettlementChainParameterRegistry parameter");

        // Call PayerRegistry.updateFeeDistributor()
        console.log("Calling PayerRegistry.updateFeeDistributor()");
        console.log("  PayerRegistry proxy: %s", _deploymentData.payerRegistryProxy);

        vm.startBroadcast(_adminPrivateKey);
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateFeeDistributor();
        vm.stopBroadcast();

        console.log("Successfully called PayerRegistry.updateFeeDistributor()");
        console.log("DistributionManager dependencies update complete");
    }

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
        console.log("Proxy:", _deploymentData.distributionManagerProxy);
        console.log("DistributionManager Predicted Addresses:");
        console.log("  Implementation:", computedImplementation_);
        console.log("  Proxy:", computedProxy_);
        if (_deploymentData.distributionManagerProxy != address(0)) {
            if (computedProxy_ != _deploymentData.distributionManagerProxy) {
                console.log("WARNING: Computed proxy address does not match config proxy address!");
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
