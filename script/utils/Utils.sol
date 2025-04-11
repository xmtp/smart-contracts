// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

library Utils {
    error InvalidProxyAddress(string outputJson_);

    VmSafe internal constant VM = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant CHAIN_ID_ANVIL_LOCALNET = 31_337;
    uint256 internal constant CHAIN_ID_XMTP_TESTNET = 241_320_161;
    uint256 internal constant CHAIN_ID_BASE_SEPOLIA = 84_532;

    string internal constant OUTPUT_ANVIL_LOCALNET = "anvil_localnet";
    string internal constant OUTPUT_XMTP_TESTNET = "xmtp_testnet";
    string internal constant OUTPUT_BASE_SEPOLIA = "base_sepolia";
    string internal constant OUTPUT_UNKNOWN = "unknown";

    function readInput(string memory inputFileName) internal view returns (string memory) {
        string memory file = getInputPath(inputFileName);
        return VM.readFile(file);
    }

    function getInputPath(string memory inputFileName) internal view returns (string memory) {
        string memory inputDir = string.concat(VM.projectRoot(), "/deployments/");
        string memory environmentDir = string.concat(resolveEnvironment(), "/");
        string memory file = string.concat(inputFileName, ".json");
        return string.concat(inputDir, environmentDir, file);
    }

    function readOutput(string memory outputFileName) internal view returns (string memory) {
        string memory file = getOutputPath(outputFileName);
        return VM.readFile(file);
    }

    function writeOutput(string memory outputJson, string memory outputFileName) internal {
        string memory outputFilePath = getOutputPath(outputFileName);
        VM.writeJson(outputJson, outputFilePath);
    }

    function getOutputPath(string memory outputFileName) internal view returns (string memory) {
        string memory outputDir = string.concat(VM.projectRoot(), "/deployments/");
        string memory environmentDir = string.concat(resolveEnvironment(), "/");
        string memory outputFilePath = string.concat(outputDir, environmentDir, outputFileName, ".json");
        return outputFilePath;
    }

    function resolveEnvironment() internal view returns (string memory) {
        string memory environment = VM.envString("ENVIRONMENT");

        if (bytes(environment).length == 0) return OUTPUT_UNKNOWN;

        return environment;
    }

    function getProxy(string memory outputJson_) internal view returns (address proxy_) {
        proxy_ = stdJson.readAddress(readOutput(outputJson_), ".addresses.proxy");
        require(address(proxy_) != address(0), InvalidProxyAddress(outputJson_));
    }

    function serializeUpgradeData(address implementation_, string memory outputJson_) internal {
        VM.writeJson(VM.toString(implementation_), getOutputPath(outputJson_), ".addresses.implementation");

        VM.writeJson(VM.toString(block.number), getOutputPath(outputJson_), ".latestUpgradeBlock");
    }
}
