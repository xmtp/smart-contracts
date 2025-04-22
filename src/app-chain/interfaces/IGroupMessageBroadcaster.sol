// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPayloadBroadcaster } from "../../abstract/interfaces/IPayloadBroadcaster.sol";

interface IGroupMessageBroadcaster is IPayloadBroadcaster {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a message is sent.
     * @param  groupId    The group ID.
     * @param  message    The message in bytes. Contains the full mls group message payload.
     * @param  sequenceId The unique sequence ID of the message.
     */
    event MessageSent(bytes32 indexed groupId, bytes message, uint64 indexed sequenceId);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Adds a message to the group.
     * @param  groupId_ The group ID.
     * @param  message_ The message in bytes.
     * @dev    Ensures the payload length is within the allowed range and increments the sequence ID.
     */
    function addMessage(bytes32 groupId_, bytes calldata message_) external;
}
