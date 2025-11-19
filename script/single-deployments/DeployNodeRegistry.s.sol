// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../Deploy.s.sol";
import { NodeRegistryDeployer } from "../deployers/NodeRegistryDeployer.sol";

contract DeployNodeRegistryScript is DeployScripts {
    error EnvironmentContainsNodeRegistry();
    error ImplementationAddressMismatch(address expected, address computed);

    function deployNodeRegistry() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        console.log("Deploying NodeRegistry");

        // Validate config address matches deterministic address before attempting deployment
        _validateImplementationAddress();

        // Deploy implementation first
        deployNodeRegistryImplementation();

        // Deploy proxy (automatically initializes and configures proxy to point at implementation)
        deployNodeRegistryProxy();

        // Update environment JSON with nodeRegistry address
        _writeNodeRegistryToEnvironment();

        console.log("NodeRegistry deployment complete");
    }

    function _validateImplementationAddress() internal view {
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        // Compute the deterministic address that will be deployed
        address computedImplementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        // Validate config address matches deterministic address before attempting deployment
        if (_deploymentData.nodeRegistryImplementation != computedImplementation_) {
            revert ImplementationAddressMismatch(_deploymentData.nodeRegistryImplementation, computedImplementation_);
        }
    }

    function _writeNodeRegistryToEnvironment() internal {
        _prepareEnvironmentJson(_ensureNoNodeRegistry);

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        vm.serializeJson("root", vm.readFile(filePath_));
        string memory json_ = vm.serializeAddress("root", "nodeRegistry", _deploymentData.nodeRegistryProxy);

        // Only update the environment JSON if broadcasting
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            vm.writeJson(json_, filePath_);
        } else {
            console.log("Not broadcasted. No writes to environment JSON.");
            console.log("NodeRegistry Proxy: %s", _deploymentData.nodeRegistryProxy);
        }
        
        console.log("NodeRegistry Implementation: %s", _deploymentData.nodeRegistryImplementation);
    }

    function _ensureNoNodeRegistry(string memory json_) internal view {
        // Copying the intent from Deploy.s.sol. Environment JSON must have any existing node registry value
        // manually removed before starting.
        if (vm.keyExists(json_, ".nodeRegistry")) {
            revert EnvironmentContainsNodeRegistry();
        }
    }

    function predictAddresses() external view {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxySalt == 0) revert ProxySaltNotSet();

        address computedImplementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        address computedProxy_ = NodeRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.nodeRegistryProxySalt
        );

        console.log("NodeRegistry Predicted Addresses");
        console.log("Implementation:", computedImplementation_);
        console.log("Proxy (calculated from salt):", computedProxy_);
        if (_deploymentData.nodeRegistryProxy != address(0)) {
            console.log("Proxy (from config JSON):", _deploymentData.nodeRegistryProxy);
            if (computedProxy_ != _deploymentData.nodeRegistryProxy) {
                console.log("WARNING: Computed proxy address does not match config proxy address!");
            }
        }
    }
}
