// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
import { IPayloadBroadcaster } from "../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { GroupMessageBroadcaster } from "../src/app-chain/GroupMessageBroadcaster.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library GroupMessageBroadcasterDeployer {
    function deployImplementation(address factory_, address registry_) internal returns (address implementation_) {
        bytes memory creationCode_ = abi.encodePacked(
            type(GroupMessageBroadcaster).creationCode,
            abi.encode(registry_)
        );

        return IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_
    ) internal returns (GroupMessageBroadcaster proxy_) {
        bytes memory initializeCallData_ = abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector);
        return GroupMessageBroadcaster(IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_));
    }
}

contract DeployGroupMessageBroadcaster is Script {}
