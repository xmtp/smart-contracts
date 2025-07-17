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
    function addMessage(bytes32 groupId_, bytes calldata message_) external {
        _revertIfPaused();
        _revertIfInvalidPayloadSize(message_.length);

        unchecked {
            emit MessageSent(groupId_, message_, ++_getPayloadBroadcasterStorage().sequenceId);
        }
    }

    /// @inheritdoc IGroupMessageBroadcaster
    function bootstrapMessages(
        bytes32[] calldata groupIds_,
        bytes[] calldata messages_,
        uint64[] calldata sequenceIds_
    ) external {
        _revertIfNotPaused();
        _revertIfNotPayloadBootstrapper();

        if (groupIds_.length != messages_.length || groupIds_.length != sequenceIds_.length) {
            revert ArrayLengthMismatch();
        }

        if (groupIds_.length == 0) revert EmptyArray();

        uint64 maxSequenceId_ = _getPayloadBroadcasterStorage().sequenceId;

        for (uint256 index_; index_ < groupIds_.length; ++index_) {
            uint64 sequenceId_ = sequenceIds_[index_];

            emit MessageSent(groupIds_[index_], messages_[index_], sequenceId_);

            if (sequenceId_ > maxSequenceId_) {
                maxSequenceId_ = sequenceId_;
            }
        }

        _getPayloadBroadcasterStorage().sequenceId = maxSequenceId_;
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function minPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.groupMessageBroadcaster.minPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.groupMessageBroadcaster.maxPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.groupMessageBroadcaster.migrator";
    }

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.groupMessageBroadcaster.paused";
    }

    /// @inheritdoc IPayloadBroadcaster
    function payloadBootstrapperParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.groupMessageBroadcaster.payloadBootstrapper";
    }
}
