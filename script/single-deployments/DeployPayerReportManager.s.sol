// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../Deploy.s.sol";
import { PayerReportManagerDeployer } from "../deployers/PayerReportManagerDeployer.sol";
import { Utils } from "../utils/Utils.sol";
import {
    ISettlementChainParameterRegistry
} from "../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";

/**
 * @title DeployPayerReportManagerScript
 * @notice Script to deploy a fresh release of the PayerReportManager contract (proxy and implementation pair)
 * @dev This script inherits from Deploy.s.sol, and has three entry points:
 * 1) deployContract() to deploy a new PayerReportManager contract (proxy and implementation pair)
 * Calls into mass deploy script Deploy.s.sol for a single deployment of PayerReportManager:
 * - Validates the proxy & implementation addresses match the deterministic address held in config JSON.
 * - Deploys the implementation & proxy (no-ops if already present on chain as was requested).
 * - Updates the environment JSON with the new payerReportManager proxy address.
 * Usage: ENVIRONMENT=testnet-dev forge script script/single-deployments/DeployPayerReportManager.s.sol:DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
 *
 * 2) updateDependencies() to update the dependencies of the PayerReportManager contract
 * - Updates the SettlementChainParameterRegistry key xmtp.payerRegistry.settler with the new PayerReportManager proxy address
 * - Calls PayerRegistry.updateSettler() to update the settler in the PayerRegistry contract
 * Usage: ENVIRONMENT=testnet-dev forge script script/single-deployments/DeployPayerReportManager.s.sol:DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "updateDependencies()" --broadcast
 *
 * 3) predictAddresses() to print the predicted addresses of the implementation & proxy (a helper function, doesn't broadcast)
 * The proxy address depends on the factory addresss, deployer address and the salt.
 * The implementation address depends on the factory address and the implementation bytecode.
 * Usage: ENVIRONMENT=testnet-dev forge script script/single-deployments/DeployPayerReportManager.s.sol:DeployPayerReportManagerScript --rpc-url base_sepolia --sig "predictAddresses()"
 */
contract DeployPayerReportManagerScript is DeployScripts {
    error EnvironmentContainsPayerReportManager();
    error ImplementationAddressMismatch(address expected, address computed);

    uint256 internal _adminPrivateKey;

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
        console.log("Updating PayerReportManager dependencies");

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
        console.log("Updating SettlementChainParameterRegistry parameter:");
        console.log("  Key: %s", settlerKey_);
        console.log("  Value (PayerReportManager proxy): %s", payerReportManagerProxy_);

        vm.startBroadcast(_adminPrivateKey);
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(settlerKey_, settlerValue_);
        vm.stopBroadcast();

        console.log("Successfully updated SettlementChainParameterRegistry parameter");

        // Call PayerRegistry.updateSettler()
        console.log("Calling PayerRegistry.updateSettler()");
        console.log("  PayerRegistry proxy: %s", _deploymentData.payerRegistryProxy);

        vm.startBroadcast(_adminPrivateKey);
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateSettler();
        vm.stopBroadcast();

        console.log("Successfully called PayerRegistry.updateSettler()");
        console.log("PayerReportManager dependencies update complete");
    }

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
        console.log("Proxy:", _deploymentData.payerReportManagerProxy);
        console.log("PayerReportManager Predicted Addresses:");
        console.log("  Implementation:", computedImplementation_);
        console.log("  Proxy:", computedProxy_);
        if (_deploymentData.payerReportManagerProxy != address(0)) {
            if (computedProxy_ != _deploymentData.payerReportManagerProxy) {
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
