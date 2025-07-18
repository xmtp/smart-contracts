// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

library Utils {
    error InvalidInputLength();

    enum ParameterType {
        Address,
        Uint
    }

    struct DeploymentData {
        address appChainGatewayImplementation;
        uint256 appChainId;
        address appChainParameterRegistryImplementation;
        address deployer;
        address distributionManagerImplementation;
        address distributionManagerProxy;
        bytes32 distributionManagerProxySalt;
        address factory;
        address factoryImplementation;
        address feeTokenImplementation;
        address feeTokenProxy;
        bytes32 feeTokenProxySalt;
        address gatewayProxy;
        bytes32 gatewayProxySalt;
        address groupMessageBroadcasterImplementation;
        address groupMessageBroadcasterProxy;
        bytes32 groupMessageBroadcasterProxySalt;
        address identityUpdateBroadcasterImplementation;
        address identityUpdateBroadcasterProxy;
        bytes32 identityUpdateBroadcasterProxySalt;
        address initializableImplementation;
        address mockUnderlyingFeeTokenImplementation;
        bytes32 mockUnderlyingFeeTokenProxySalt;
        address nodeRegistryImplementation;
        address nodeRegistryProxy;
        bytes32 nodeRegistryProxySalt;
        address parameterRegistryProxy;
        bytes32 parameterRegistryProxySalt;
        address payerRegistryImplementation;
        address payerRegistryProxy;
        bytes32 payerRegistryProxySalt;
        address payerReportManagerImplementation;
        address payerReportManagerProxy;
        bytes32 payerReportManagerProxySalt;
        address rateRegistryImplementation;
        address rateRegistryProxy;
        bytes32 rateRegistryProxySalt;
        address settlementChainGatewayImplementation;
        uint256 settlementChainId;
        address settlementChainParameterRegistryAdmin1;
        address settlementChainParameterRegistryAdmin2;
        address settlementChainParameterRegistryAdmin3;
        address settlementChainParameterRegistryImplementation;
        address underlyingFeeToken;
    }

    VmSafe internal constant VM = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    function parseDeploymentData(
        string memory filePath_
    ) internal view returns (DeploymentData memory deploymentData_) {
        string memory json_ = VM.readFile(filePath_);

        deploymentData_.appChainGatewayImplementation = stdJson.readAddress(json_, ".appChainGatewayImplementation");
        deploymentData_.appChainId = stdJson.readUint(json_, ".appChainId");
        deploymentData_.appChainParameterRegistryImplementation = stdJson.readAddress(
            json_,
            ".appChainParameterRegistryImplementation"
        );
        deploymentData_.deployer = stdJson.readAddress(json_, ".deployer");
        deploymentData_.distributionManagerImplementation = stdJson.readAddress(
            json_,
            ".distributionManagerImplementation"
        );
        deploymentData_.distributionManagerProxy = stdJson.readAddress(json_, ".distributionManagerProxy");
        deploymentData_.distributionManagerProxySalt = stringToBytes32(
            stdJson.readString(json_, ".distributionManagerProxySalt")
        );
        deploymentData_.factory = stdJson.readAddress(json_, ".factory");
        deploymentData_.factoryImplementation = stdJson.readAddress(json_, ".factoryImplementation");
        deploymentData_.feeTokenImplementation = stdJson.readAddress(json_, ".feeTokenImplementation");
        deploymentData_.feeTokenProxy = stdJson.readAddress(json_, ".feeTokenProxy");
        deploymentData_.feeTokenProxySalt = stringToBytes32(stdJson.readString(json_, ".feeTokenProxySalt"));
        deploymentData_.gatewayProxy = stdJson.readAddress(json_, ".gatewayProxy");
        deploymentData_.gatewayProxySalt = stringToBytes32(stdJson.readString(json_, ".gatewayProxySalt"));
        deploymentData_.groupMessageBroadcasterImplementation = stdJson.readAddress(
            json_,
            ".groupMessageBroadcasterImplementation"
        );
        deploymentData_.groupMessageBroadcasterProxy = stdJson.readAddress(json_, ".groupMessageBroadcasterProxy");
        deploymentData_.groupMessageBroadcasterProxySalt = stringToBytes32(
            stdJson.readString(json_, ".groupMessageBroadcasterProxySalt")
        );
        deploymentData_.identityUpdateBroadcasterImplementation = stdJson.readAddress(
            json_,
            ".identityUpdateBroadcasterImplementation"
        );
        deploymentData_.identityUpdateBroadcasterProxy = stdJson.readAddress(json_, ".identityUpdateBroadcasterProxy");
        deploymentData_.identityUpdateBroadcasterProxySalt = stringToBytes32(
            stdJson.readString(json_, ".identityUpdateBroadcasterProxySalt")
        );
        deploymentData_.initializableImplementation = stdJson.readAddress(json_, ".initializableImplementation");
        deploymentData_.mockUnderlyingFeeTokenImplementation = stdJson.readAddressOr(
            json_,
            ".mockUnderlyingFeeTokenImplementation",
            address(0)
        );
        deploymentData_.mockUnderlyingFeeTokenProxySalt = stringToBytes32(
            stdJson.readStringOr(json_, ".mockUnderlyingFeeTokenProxySalt", "")
        );
        deploymentData_.nodeRegistryImplementation = stdJson.readAddress(json_, ".nodeRegistryImplementation");
        deploymentData_.nodeRegistryProxy = stdJson.readAddress(json_, ".nodeRegistryProxy");
        deploymentData_.nodeRegistryProxySalt = stringToBytes32(stdJson.readString(json_, ".nodeRegistryProxySalt"));
        deploymentData_.parameterRegistryProxy = stdJson.readAddress(json_, ".parameterRegistryProxy");
        deploymentData_.parameterRegistryProxySalt = stringToBytes32(
            stdJson.readString(json_, ".parameterRegistryProxySalt")
        );
        deploymentData_.payerRegistryImplementation = stdJson.readAddress(json_, ".payerRegistryImplementation");
        deploymentData_.payerRegistryProxy = stdJson.readAddress(json_, ".payerRegistryProxy");
        deploymentData_.payerRegistryProxySalt = stringToBytes32(stdJson.readString(json_, ".payerRegistryProxySalt"));
        deploymentData_.payerReportManagerImplementation = stdJson.readAddress(
            json_,
            ".payerReportManagerImplementation"
        );
        deploymentData_.payerReportManagerProxy = stdJson.readAddress(json_, ".payerReportManagerProxy");
        deploymentData_.payerReportManagerProxySalt = stringToBytes32(
            stdJson.readString(json_, ".payerReportManagerProxySalt")
        );
        deploymentData_.rateRegistryImplementation = stdJson.readAddress(json_, ".rateRegistryImplementation");
        deploymentData_.rateRegistryProxy = stdJson.readAddress(json_, ".rateRegistryProxy");
        deploymentData_.rateRegistryProxySalt = stringToBytes32(stdJson.readString(json_, ".rateRegistryProxySalt"));
        deploymentData_.settlementChainGatewayImplementation = stdJson.readAddress(
            json_,
            ".settlementChainGatewayImplementation"
        );
        deploymentData_.settlementChainId = stdJson.readUint(json_, ".settlementChainId");
        deploymentData_.settlementChainParameterRegistryAdmin1 = stdJson.readAddress(
            json_,
            ".settlementChainParameterRegistryAdmin1"
        );
        deploymentData_.settlementChainParameterRegistryAdmin2 = stdJson.readAddress(
            json_,
            ".settlementChainParameterRegistryAdmin2"
        );
        deploymentData_.settlementChainParameterRegistryAdmin3 = stdJson.readAddress(
            json_,
            ".settlementChainParameterRegistryAdmin3"
        );
        deploymentData_.settlementChainParameterRegistryImplementation = stdJson.readAddress(
            json_,
            ".settlementChainParameterRegistryImplementation"
        );
        deploymentData_.underlyingFeeToken = stdJson.readAddress(json_, ".underlyingFeeToken");
    }

    function parseStartingParameters(
        string memory filePath_
    ) internal view returns (string[] memory keys_, bytes32[] memory values_) {
        string memory json_ = VM.readFile(filePath_);

        string[] memory startingKeys_ = new string[](15);
        startingKeys_[0] = "xmtp.nodeRegistry.admin";
        startingKeys_[1] = "xmtp.nodeRegistry.maxCanonicalNodes";
        startingKeys_[2] = "xmtp.payerRegistry.settler";
        startingKeys_[3] = "xmtp.payerRegistry.feeDistributor";
        startingKeys_[4] = "xmtp.payerRegistry.minimumDeposit";
        startingKeys_[5] = "xmtp.payerRegistry.withdrawLockPeriod";
        startingKeys_[6] = "xmtp.rateRegistry.messageFee";
        startingKeys_[7] = "xmtp.rateRegistry.storageFee";
        startingKeys_[8] = "xmtp.rateRegistry.congestionFee";
        startingKeys_[9] = "xmtp.rateRegistry.targetRatePerMinute";
        startingKeys_[10] = "xmtp.groupMessageBroadcaster.minPayloadSize";
        startingKeys_[11] = "xmtp.groupMessageBroadcaster.maxPayloadSize";
        startingKeys_[12] = "xmtp.identityUpdateBroadcaster.minPayloadSize";
        startingKeys_[13] = "xmtp.identityUpdateBroadcaster.maxPayloadSize";

        startingKeys_[14] = string.concat(
            "xmtp.settlementChainGateway.inbox.",
            VM.parseJsonKeys(json_, "xmtp.settlementChainGateway.inbox")[0]
        );

        ParameterType[] memory parameterTypes_ = new ParameterType[](15);
        parameterTypes_[0] = ParameterType.Address;
        parameterTypes_[1] = ParameterType.Uint;
        parameterTypes_[2] = ParameterType.Address;
        parameterTypes_[3] = ParameterType.Address;
        parameterTypes_[4] = ParameterType.Uint;
        parameterTypes_[5] = ParameterType.Uint;
        parameterTypes_[6] = ParameterType.Uint;
        parameterTypes_[7] = ParameterType.Uint;
        parameterTypes_[8] = ParameterType.Uint;
        parameterTypes_[9] = ParameterType.Uint;
        parameterTypes_[10] = ParameterType.Uint;
        parameterTypes_[11] = ParameterType.Uint;
        parameterTypes_[12] = ParameterType.Uint;
        parameterTypes_[13] = ParameterType.Uint;
        parameterTypes_[14] = ParameterType.Address;

        uint256 count_ = 0;

        for (uint256 index_; index_ < startingKeys_.length; ++index_) {
            if (!stdJson.keyExists(json_, string.concat(".startingParameters.", startingKeys_[index_]))) continue;

            ++count_;
        }

        keys_ = new string[](count_);
        values_ = new bytes32[](count_);

        uint256 outputIndex_ = 0;
        for (uint256 index_; index_ < startingKeys_.length; ++index_) {
            if (!stdJson.keyExists(json_, string.concat(".startingParameters.", startingKeys_[index_]))) continue;

            keys_[outputIndex_] = startingKeys_[index_];

            values_[outputIndex_] = parameterTypes_[index_] == ParameterType.Address
                ? parseAndEncodeAddressParameter(json_, string.concat(".startingParameters.", startingKeys_[index_]))
                : parseAndEncodeUintParameter(json_, string.concat(".startingParameters.", startingKeys_[index_]));

            ++outputIndex_;
        }
    }

    function parseAndEncodeAddressParameter(
        string memory json_,
        string memory key_
    ) internal pure returns (bytes32 value_) {
        value_ = bytes32(uint256(uint160(stdJson.readAddress(json_, key_))));
    }

    function parseAndEncodeUintParameter(
        string memory json_,
        string memory key_
    ) internal pure returns (bytes32 value_) {
        value_ = bytes32(stdJson.readUint(json_, key_));
    }

    function stringToBytes32(string memory input_) internal pure returns (bytes32 output_) {
        if (bytes(input_).length > 32) revert InvalidInputLength();

        return bytes32(abi.encodePacked(input_));
    }

    function bytes32ToString(bytes32 input_) internal pure returns (string memory output_) {
        return string(abi.encodePacked(input_));
    }
}
