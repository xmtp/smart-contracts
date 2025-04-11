// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { GroupMessageBroadcaster } from "../../src/app-chain/GroupMessageBroadcaster.sol";

import { Utils } from "../utils/Utils.sol";
import { Environment } from "../utils/Environment.sol";

contract UpgradeGroupMessageBroadcaster is Utils, Environment {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address upgrader = vm.addr(privateKey);

        GroupMessageBroadcaster proxy = GroupMessageBroadcaster(_getProxy(XMTP_GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON));

        address registry = _getProxy(XMTP_PARAMETER_REGISTRY_OUTPUT_JSON);

        vm.startBroadcast(privateKey);

        // Deploy the new implementation contract.
        address newImplementation = address(new GroupMessageBroadcaster(registry));

        require(newImplementation != address(0), "Implementation deployment failed");

        vm.stopBroadcast();

        _serializeUpgradeData(newImplementation, XMTP_GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON);
    }
}
