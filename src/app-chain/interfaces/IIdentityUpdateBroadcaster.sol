// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPayloadBroadcaster } from "../../abstract/interfaces/IPayloadBroadcaster.sol";

/**
 * @title  Interface for an App Chain Identity Update Broadcaster.
 * @notice The IdentityUpdateBroadcaster is an identity payload broadcaster on an app chain.
 */
interface IIdentityUpdateBroadcaster is IPayloadBroadcaster {
    /* ============ Events ============ */

    /**
     * @notice Emitted when an identity update is sent.
     * @param  inboxId    The inbox ID.
     * @param  update     The identity update in bytes. Contains the full MLS identity update payload.
     * @param  sequenceId The unique sequence ID of the identity update.
     */
    event IdentityUpdateCreated(bytes32 indexed inboxId, bytes update, uint64 indexed sequenceId);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the array lengths do not match.
    error ArrayLengthMismatch();

    /// @notice Thrown when a supplied array is empty.
    error EmptyArray();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Adds an identity update to an specific inbox ID.
     * @param  inboxId_        The inbox ID.
     * @param  identityUpdate_ The identity update in bytes.
     * @dev    Ensures the payload length is within the allowed range and increments the sequence ID.
     */
    function addIdentityUpdate(bytes32 inboxId_, bytes calldata identityUpdate_) external;

    /**
     * @notice Bootstraps identity updates to satisfy a migration.
     * @param  inboxIds_        The inbox IDs.
     * @param  identityUpdates_ The identity updates in bytes.
     * @param  sequenceIds_     The sequence IDs.
     */
    function bootstrapIdentityUpdates(
        bytes32[] calldata inboxIds_,
        bytes[] calldata identityUpdates_,
        uint64[] calldata sequenceIds_
    ) external;
}
