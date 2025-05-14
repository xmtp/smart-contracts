// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IIdentityUpdateBroadcaster } from "./interfaces/IIdentityUpdateBroadcaster.sol";
import { IPayloadBroadcaster } from "../abstract/interfaces/IPayloadBroadcaster.sol";

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
