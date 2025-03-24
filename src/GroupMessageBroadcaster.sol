// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IGroupMessageBroadcaster } from "./interfaces/IGroupMessageBroadcaster.sol";
import { IPayloadBroadcaster } from "./interfaces/IPayloadBroadcaster.sol";

import { PayloadBroadcaster } from "./PayloadBroadcaster.sol";

/// @title XMTP Group Message Broadcaster Contract
contract GroupMessageBroadcaster is IGroupMessageBroadcaster, PayloadBroadcaster {
    /* ============ Constructor ============ */

    /**
     * @notice Constructor for immutables.
     * @param  registry_ The address of the parameter registry.
     */
    constructor(address registry_) PayloadBroadcaster(registry_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IGroupMessageBroadcaster
    function addMessage(bytes32 groupId_, bytes calldata message_) external whenNotPaused {
        _revertIfInvalidPayloadSize(message_.length);

        // Increment sequence ID safely using unchecked to save gas.
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
        return "xmtp.gmb.minPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.gmb.maxPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.gmb.migrator";
    }

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (bytes memory key_)
    {
        return "xmtp.gmb.paused";
    }
}
