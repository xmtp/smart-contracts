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

    function readInput(string memory inputFileName_) internal view returns (string memory input_) {
        string memory file_ = getInputPath(inputFileName_);
        return VM.readFile(file_);
    }

    function getInputPath(string memory inputFileName_) internal view returns (string memory inputPath_) {
        string memory inputDir_ = string.concat(VM.projectRoot(), "/deployments/");
        string memory environmentDir_ = string.concat(resolveEnvironment(), "/");
        string memory file_ = string.concat(inputFileName_, ".json");
        return string.concat(inputDir_, environmentDir_, file_);
    }

    function readOutput(string memory outputFileName_) internal view returns (string memory output_) {
        string memory file_ = getOutputPath(outputFileName_);
        return VM.readFile(file_);
    }

    function writeOutput(string memory outputJson_, string memory outputFileName_) internal {
        string memory outputFilePath_ = getOutputPath(outputFileName_);
        VM.writeJson(outputJson_, outputFilePath_);
    }

    function getOutputPath(string memory outputFileName_) internal view returns (string memory outputFilePath_) {
        string memory outputDir_ = string.concat(VM.projectRoot(), "/deployments/");
        string memory environmentDir_ = string.concat(resolveEnvironment(), "/");
        return string.concat(outputDir_, environmentDir_, outputFileName_, ".json");
    }

    function resolveEnvironment() internal view returns (string memory environment_) {
        environment_ = VM.envString("ENVIRONMENT");

        return (bytes(environment_).length == 0) ? OUTPUT_UNKNOWN : environment_;
    }

    function getProxy(string memory outputJson_) internal view returns (address proxy_) {
        proxy_ = stdJson.readAddress(readOutput(outputJson_), ".addresses.proxy");
        require(address(proxy_) != address(0), InvalidProxyAddress(outputJson_));
    }

    function serializeUpgradeData(address implementation_, string memory outputJson_) internal {
        VM.writeJson(VM.toString(implementation_), getOutputPath(outputJson_), ".addresses.implementation");
        VM.writeJson(VM.toString(block.number), getOutputPath(outputJson_), ".latestUpgradeBlock");
    }

    function buildFactoryJson(address deployer_, address implementation_) internal returns (string memory json_) {
        json_ = VM.serializeUint("", "chainId", block.chainid);
        json_ = VM.serializeAddress("", "deployer", deployer_);
        json_ = VM.serializeAddress("", "implementation", implementation_);
        json_ = VM.serializeUint("", "deploymentBlock", block.number);
    }

    function buildImplementationJson(
        address factory_,
        address implementation_,
        bytes memory constructorArguments_
    ) internal returns (string memory json_) {
        json_ = VM.serializeUint("", "chainId", block.chainid);
        json_ = VM.serializeAddress("", "factory", factory_);
        json_ = VM.serializeAddress("", "implementation", implementation_);
        json_ = VM.serializeBytes("", "constructorArguments", constructorArguments_);
        json_ = VM.serializeUint("", "deploymentBlock", block.number);
    }

    function buildProxyJson(
        address factory_,
        address deployer_,
        address proxy_,
        bytes memory constructorArguments_
    ) internal returns (string memory json_) {
        json_ = VM.serializeUint("", "chainId", block.chainid);
        json_ = VM.serializeAddress("", "factory", factory_);
        json_ = VM.serializeAddress("", "deployer", deployer_);
        json_ = VM.serializeAddress("", "proxy", proxy_);
        json_ = VM.serializeBytes("", "constructorArguments", constructorArguments_);
        json_ = VM.serializeUint("", "deploymentBlock", block.number);
    }
}
