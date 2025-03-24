// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPayloadBroadcaster } from "../src/interfaces/IPayloadBroadcaster.sol";

import { IdentityUpdateBroadcaster } from "../src/IdentityUpdateBroadcaster.sol";

import { DeployProxiedContract } from "./utils/DeployProxiedContract.s.sol";

contract DeployIdentityUpdateBroadcasterScript is DeployProxiedContract {
    function _getImplementationCreationCode() internal pure override returns (bytes memory) {
        return abi.encodePacked(type(IdentityUpdateBroadcaster).creationCode);
    }

    function _getAdminEnvVar() internal pure override returns (string memory) {
        return "XMTP_IDENTITY_UPDATE_BROADCASTER_ADMIN_ADDRESS";
    }

    function _getOutputFilePath() internal pure override returns (string memory) {
        return XMTP_IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON;
    }

    function _getProxySalt() internal pure override returns (bytes32) {
        return keccak256(abi.encodePacked("IdentityUpdateBroadcasterProxy"));
    }

    function _getImplementationSalt() internal pure override returns (bytes32) {
        return keccak256(abi.encodePacked("IdentityUpdateBroadcaster"));
    }

    function _getInitializeCalldata() internal view override returns (bytes memory) {
        address admin = vm.envAddress("XMTP_IDENTITY_UPDATE_BROADCASTER_ADMIN_ADDRESS");
        require(admin != address(0), "XMTP_IDENTITY_UPDATE_BROADCASTER_ADMIN_ADDRESS not set");

        return abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector, admin);
    }
}
