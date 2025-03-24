// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPayloadBroadcaster } from "./IPayloadBroadcaster.sol";

interface IIdentityUpdateBroadcaster is IPayloadBroadcaster {
    /* ============ Events ============ */

    /**
     * @notice Emitted when an identity update is sent.
     * @param  inboxId    The inbox ID.
     * @param  update     The identity update in bytes. Contains the full mls identity update payload.
     * @param  sequenceId The unique sequence ID of the identity update.
     */
    event IdentityUpdateCreated(bytes32 indexed inboxId, bytes update, uint64 indexed sequenceId);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Adds an identity update to an specific inbox ID.
     * @param  inboxId_        The inbox ID.
     * @param  identityUpdate_ The identity update in bytes.
     * @dev    Ensures the payload length is within the allowed range and increments the sequence ID.
     */
    function addIdentityUpdate(bytes32 inboxId_, bytes calldata identityUpdate_) external;
}
