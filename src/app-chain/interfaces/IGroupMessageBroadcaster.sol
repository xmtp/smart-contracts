// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPayloadBroadcaster } from "../../abstract/interfaces/IPayloadBroadcaster.sol";

/**
 * @title  Interface for an App Chain Group Message Broadcaster.
 * @notice The GroupMessageBroadcaster is a group message payload broadcaster on an app chain.
 */
interface IGroupMessageBroadcaster is IPayloadBroadcaster {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a message is sent.
     * @param  groupId    The group ID.
     * @param  message    The message in bytes. Contains the full MLS group message payload.
     * @param  sequenceId The unique sequence ID of the message.
     */
    event MessageSent(bytes16 indexed groupId, bytes message, uint64 indexed sequenceId);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the length of input arrays don't match.
    error ArrayLengthMismatch();

    /// @notice Thrown when a supplied array is empty.
    error EmptyArray();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Adds a message to the group.
     * @param  groupId_ The group ID.
     * @param  message_ The message in bytes.
     * @dev    Ensures the payload length is within the allowed range and increments the sequence ID.
     */
    function addMessage(bytes16 groupId_, bytes calldata message_) external;

    /**
     * @notice Bootstraps messages to satisfy a migration.
     * @param  groupIds_    The group IDs.
     * @param  messages_    The messages in bytes.
     * @param  sequenceIds_ The sequence IDs.
     */
    function bootstrapMessages(
        bytes16[] calldata groupIds_,
        bytes[] calldata messages_,
        uint64[] calldata sequenceIds_
    ) external;
}
