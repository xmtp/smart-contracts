// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPayloadBroadcaster } from "../abstract/interfaces/IPayloadBroadcaster.sol";

import { PayloadBroadcaster } from "../abstract/PayloadBroadcaster.sol";

import { IIdentityUpdateBroadcaster } from "./interfaces/IIdentityUpdateBroadcaster.sol";

/// @title XMTP Identity Update Broadcaster Contract
contract IdentityUpdateBroadcaster is IIdentityUpdateBroadcaster, PayloadBroadcaster {
    /* ============ Constructor ============ */

    /**
     * @notice Constructor for immutables.
     * @param  parameterRegistry_ The address of the parameter registry.
     */
    constructor(address parameterRegistry_) PayloadBroadcaster(parameterRegistry_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IIdentityUpdateBroadcaster
    function addIdentityUpdate(bytes32 inboxId_, bytes calldata identityUpdate_) external whenNotPaused {
        _revertIfInvalidPayloadSize(identityUpdate_.length);

        // Increment sequence ID safely using unchecked to save gas.
        unchecked {
            emit IdentityUpdateCreated(inboxId_, identityUpdate_, ++_getPayloadBroadcasterStorage().sequenceId);
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
        return "xmtp.identityUpdateBroadcaster.minPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.maxPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.migrator";
    }

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.paused";
    }
}
