// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

library Utils {
    struct DeploymentData {
        address deployer;
        address appChainNativeToken;
        address factory;
        address settlementChainParameterRegistryImplementation;
        address appChainParameterRegistryImplementation;
        bytes32 parameterRegistryProxySalt;
        address parameterRegistryProxy;
        address settlementChainParameterRegistryAdmin1;
        address settlementChainParameterRegistryAdmin2;
        address settlementChainParameterRegistryAdmin3;
        address settlementChainGatewayImplementation;
        address appChainGatewayImplementation;
        bytes32 gatewayProxySalt;
        address gatewayProxy;
        address groupMessageBroadcasterImplementation;
        bytes32 groupMessageBroadcasterProxySalt;
        address groupMessageBroadcasterProxy;
        address identityUpdateBroadcasterImplementation;
        bytes32 identityUpdateBroadcasterProxySalt;
        address identityUpdateBroadcasterProxy;
        address nodeRegistryImplementation;
        bytes32 nodeRegistryProxySalt;
        address nodeRegistryProxy;
        address rateRegistryImplementation;
        bytes32 rateRegistryProxySalt;
        address rateRegistryProxy;
        address payerRegistryImplementation;
        bytes32 payerRegistryProxySalt;
        address payerRegistryProxy;
    }

    error InvalidProxyAddress(string outputJson_);

    VmSafe internal constant VM = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant CHAIN_ID_ANVIL_LOCALNET = 31_337;
    uint256 internal constant CHAIN_ID_XMTP_TESTNET = 241_320_161;
    uint256 internal constant CHAIN_ID_BASE_SEPOLIA = 84_532;

    string internal constant OUTPUT_ANVIL_LOCALNET = "anvil_localnet";
    string internal constant OUTPUT_XMTP_TESTNET = "xmtp_testnet";
    string internal constant OUTPUT_BASE_SEPOLIA = "base_sepolia";
    string internal constant OUTPUT_UNKNOWN = "unknown";

    string internal constant FACTORY_OUTPUT_JSON = "Factory";
    string internal constant SETTLEMENT_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON = "SettlementChainParameterRegistry";
    string internal constant APP_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON = "AppChainParameterRegistry";
    string internal constant SETTLEMENT_CHAIN_GATEWAY_OUTPUT_JSON = "SettlementChainGateway";
    string internal constant APP_CHAIN_GATEWAY_OUTPUT_JSON = "AppChainGateway";
    string internal constant GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON = "GroupMessageBroadcaster";
    string internal constant IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON = "IdentityUpdateBroadcaster";
    string internal constant NODE_REGISTRY_OUTPUT_JSON = "NodeRegistry";
    string internal constant RATE_REGISTRY_OUTPUT_JSON = "RateRegistry";
    string internal constant PAYER_REGISTRY_OUTPUT_JSON = "PayerRegistry";

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

    function parseDeploymentData(
        string memory filePath_
    ) internal view returns (DeploymentData memory deploymentData_) {
        return abi.decode(VM.parseJson(VM.readFile(filePath_)), (DeploymentData));
    }
}
