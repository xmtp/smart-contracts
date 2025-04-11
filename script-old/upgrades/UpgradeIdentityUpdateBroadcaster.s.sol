// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IdentityUpdateBroadcaster } from "../../src/app-chain/IdentityUpdateBroadcaster.sol";

import { Utils } from "../utils/Utils.sol";
import { Environment } from "../utils/Environment.sol";

contract UpgradeIdentityUpdateBroadcaster is Utils, Environment {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address upgrader = vm.addr(privateKey);

        IdentityUpdateBroadcaster proxy = IdentityUpdateBroadcaster(
            _getProxy(XMTP_IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON)
        );

        address registry = _getProxy(XMTP_PARAMETER_REGISTRY_OUTPUT_JSON);

        vm.startBroadcast(privateKey);

        // Deploy the new implementation contract.
        address newImplementation = address(new IdentityUpdateBroadcaster(registry));

        require(newImplementation != address(0), "Implementation deployment failed");

        vm.stopBroadcast();

        _serializeUpgradeData(newImplementation, XMTP_IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON);
    }
}
