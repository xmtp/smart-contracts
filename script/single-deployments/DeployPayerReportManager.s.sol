// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../Deploy.s.sol";
import { PayerReportManagerDeployer } from "../deployers/PayerReportManagerDeployer.sol";
import { Utils } from "../utils/Utils.sol";

/**
 * @title DeployPayerReportManagerScript
 * @notice Script to deploy a fresh release of the PayerReportManager contract (proxy and implementation pair)
 * @dev Calls into mass deploy script Deploy.s.sol for a single deployment of PayerReportManager:
 * - Validates the proxy & implementation addresses match the deterministic address held in config JSON.
 * - Deploys the implementation & proxy (no-ops if already present on chain as was requested).
 * - Updates the environment JSON with the new payerReportManager proxy address.
 *
 * Script has two entry points, a deployer and an address helper:
 * 1) deployPayerReportManager() to deploy a new PayerReportManager contract (proxy and implementation pair)
 * Usage: ENVIRONMENT=testnet-dev forge script script/single-deployments/DeployPayerReportManager.s.sol:DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "deployPayerReportManager()" --broadcast
 *
 * 2) predictAddresses() to print the predicted addresses of the implementation & proxy
 * The proxy address depends on the factory addresss, deployer address and the salt.
 * The implementation address depends on the factory address and the implementation bytecode.
 * Usage: ENVIRONMENT=testnet-dev forge script script/single-deployments/DeployPayerReportManager.s.sol:DeployPayerReportManagerScript --rpc-url base_sepolia --sig "predictAddresses()"
 */
contract DeployPayerReportManagerScript is DeployScripts {
    error EnvironmentContainsPayerReportManager();
    error ImplementationAddressMismatch(address expected, address computed);

    function deployPayerReportManager() external {
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
