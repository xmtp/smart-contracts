// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../../lib/forge-std/src/Script.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

contract Utils is Script {
    error InvalidProxyAddress(string outputJson_);

    uint256 constant CHAIN_ID_ANVIL_LOCALNET = 31_337;
    uint256 constant CHAIN_ID_XMTP_TESTNET = 241_320_161;
    uint256 constant CHAIN_ID_BASE_SEPOLIA = 84_532;

    string constant OUTPUT_ANVIL_LOCALNET = "anvil_localnet";
    string constant OUTPUT_XMTP_TESTNET = "xmtp_testnet";
    string constant OUTPUT_BASE_SEPOLIA = "base_sepolia";
    string constant OUTPUT_UNKNOWN = "unknown";

    function readInput(string memory inputFileName) internal view returns (string memory) {
        string memory file = getInputPath(inputFileName);
        return vm.readFile(file);
    }

    function getInputPath(string memory inputFileName) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/deployments/");
        string memory environmentDir = string.concat(_resolveEnvironment(), "/");
        string memory file = string.concat(inputFileName, ".json");
        return string.concat(inputDir, environmentDir, file);
    }

    function readOutput(string memory outputFileName) internal view returns (string memory) {
        string memory file = getOutputPath(outputFileName);
        return vm.readFile(file);
    }

    function writeOutput(string memory outputJson, string memory outputFileName) internal {
        string memory outputFilePath = getOutputPath(outputFileName);
        vm.writeJson(outputJson, outputFilePath);
    }

    function getOutputPath(string memory outputFileName) internal view returns (string memory) {
        string memory outputDir = string.concat(vm.projectRoot(), "/deployments/");
        string memory environmentDir = string.concat(_resolveEnvironment(), "/");
        string memory outputFilePath = string.concat(outputDir, environmentDir, outputFileName, ".json");
        return outputFilePath;
    }

    function _resolveEnvironment() internal view returns (string memory) {
        string memory environment = vm.envString("ENVIRONMENT");

        if (bytes(environment).length == 0) return OUTPUT_UNKNOWN;

        return environment;
    }

    function _getProxy(string memory outputJson_) internal view returns (address proxy_) {
        proxy_ = stdJson.readAddress(readOutput(outputJson_), ".addresses.proxy");
        require(address(proxy_) != address(0), InvalidProxyAddress(outputJson_));
    }

    function _serializeUpgradeData(address implementation_, string memory outputJson_) internal {
        vm.writeJson(vm.toString(implementation_), getOutputPath(outputJson_), ".addresses.implementation");
        vm.writeJson(vm.toString(block.number), getOutputPath(outputJson_), ".latestUpgradeBlock");
    }
}
