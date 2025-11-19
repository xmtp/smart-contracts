// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../Deploy.s.sol";

contract DeployNodeRegistryScript is DeployScripts {
    error EnvironmentContainsNodeRegistry();

    function deployNodeRegistry() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        console.log("Deploying NodeRegistry");

        // Deploy implementation first
        deployNodeRegistryImplementation();

        // Deploy proxy (automatically initializes and configures proxy to point at implementation)
        deployNodeRegistryProxy();

        // Update environment JSON with nodeRegistry address
        _writeNodeRegistryToEnvironment();

        console.log("NodeRegistry deployment complete");
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
        }
        console.log("NodeRegistry Proxy: %s", _deploymentData.nodeRegistryProxy);
        console.log("NodeRegistry Implementation: %s", _deploymentData.nodeRegistryImplementation);
    }

    function _ensureNoNodeRegistry(string memory json_) internal view {
        // Copying intent from mass deploy Deploy.s.sol, is that the environment JSON must
        // have the node registry value manaully removed before starting.
        if (vm.keyExists(json_, ".nodeRegistry")) {
            revert EnvironmentContainsNodeRegistry();
        }
    }
}
