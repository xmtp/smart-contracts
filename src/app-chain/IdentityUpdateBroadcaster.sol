// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IIdentityUpdateBroadcaster } from "./interfaces/IIdentityUpdateBroadcaster.sol";
import { IPayloadBroadcaster } from "../abstract/interfaces/IPayloadBroadcaster.sol";
import { IVersioned } from "../abstract/interfaces/IVersioned.sol";

import { PayloadBroadcaster } from "../abstract/PayloadBroadcaster.sol";

/**
 * @title  Implementation for an App Chain Identity Update Broadcaster.
 * @notice An IdentityUpdateBroadcaster is an identity payload broadcaster on an app chain.
 */
contract IdentityUpdateBroadcaster is IIdentityUpdateBroadcaster, PayloadBroadcaster {
    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     */
    constructor(address parameterRegistry_) PayloadBroadcaster(parameterRegistry_) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IIdentityUpdateBroadcaster
    function addIdentityUpdate(bytes32 inboxId_, bytes calldata identityUpdate_) external {
        _revertIfPaused();
        _revertIfInvalidPayloadSize(identityUpdate_.length);

        unchecked {
            emit IdentityUpdateCreated(inboxId_, identityUpdate_, ++_getPayloadBroadcasterStorage().sequenceId);
        }
    }

    /// @inheritdoc IIdentityUpdateBroadcaster
    function bootstrapIdentityUpdates(
        bytes32[] calldata inboxIds_,
        bytes[] calldata identityUpdates_,
        uint64[] calldata sequenceIds_
    ) external {
        _revertIfNotPaused();
        _revertIfNotPayloadBootstrapper();

        if (inboxIds_.length != identityUpdates_.length || inboxIds_.length != sequenceIds_.length) {
            revert ArrayLengthMismatch();
        }

        if (inboxIds_.length == 0) revert EmptyArray();

        uint64 maxSequenceId_ = _getPayloadBroadcasterStorage().sequenceId;

        for (uint256 index_; index_ < inboxIds_.length; ++index_) {
            uint64 sequenceId_ = sequenceIds_[index_];

            emit IdentityUpdateCreated(inboxIds_[index_], identityUpdates_[index_], sequenceId_);

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
        return "xmtp.identityUpdateBroadcaster.minPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.maxPayloadSize";
    }

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.migrator";
    }

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.paused";
    }

    /// @inheritdoc IPayloadBroadcaster
    function payloadBootstrapperParameterKey()
        public
        pure
        override(IPayloadBroadcaster, PayloadBroadcaster)
        returns (string memory key_)
    {
        return "xmtp.identityUpdateBroadcaster.payloadBootstrapper";
    }

    /// @inheritdoc IVersioned
    function version() external pure returns (string memory version_) {
        return "0.1.0";
    }
}
