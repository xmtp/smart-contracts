// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IGroupMessageBroadcaster } from "./interfaces/IGroupMessageBroadcaster.sol";
import { IPayloadBroadcaster } from "../abstract/interfaces/IPayloadBroadcaster.sol";

import { PayloadBroadcaster } from "../abstract/PayloadBroadcaster.sol";

/**
 * @title  Implementation for an App Chain Group Message Broadcaster.
 * @notice A GroupMessageBroadcaster is a group message payload broadcaster on an app chain.
 */
contract GroupMessageBroadcaster is IGroupMessageBroadcaster, PayloadBroadcaster {
    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     */
    constructor(address parameterRegistry_) PayloadBroadcaster(parameterRegistry_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IGroupMessageBroadcaster
    function addMessage(bytes32 groupId_, bytes calldata message_) external whenNotPaused {
        _revertIfInvalidPayloadSize(message_.length);

        unchecked {
            emit MessageSent(groupId_, message_, ++_getPayloadBroadcasterStorage().sequenceId);
        }
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function minPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.groupMessageBroadcaster.minPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.groupMessageBroadcaster.maxPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.groupMessageBroadcaster.migrator";
    }

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.groupMessageBroadcaster.paused";
    }
}
