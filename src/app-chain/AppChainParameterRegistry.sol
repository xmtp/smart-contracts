// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IAppChainParameterRegistry } from "./interfaces/IAppChainParameterRegistry.sol";
import { IParameterRegistry } from "../abstract/interfaces/IParameterRegistry.sol";
import { IVersioned } from "../abstract/interfaces/IVersioned.sol";

import { ParameterRegistry } from "../abstract/ParameterRegistry.sol";

/**
 * @title  Implementation for an App Chain Parameter Registry.
 * @notice An AppChainParameterRegistry is a parameter registry used by the protocol contracts on an app chain.
 */
contract AppChainParameterRegistry is IAppChainParameterRegistry, ParameterRegistry {
    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IParameterRegistry
    function migratorParameterKey()
        public
        pure
        override(IParameterRegistry, ParameterRegistry)
        returns (string memory key_)
    {
        return "xmtp.appChainParameterRegistry.migrator";
    }

    /// @inheritdoc IParameterRegistry
    function adminParameterKey()
        public
        pure
        override(IParameterRegistry, ParameterRegistry)
        returns (string memory key_)
    {
        return "xmtp.appChainParameterRegistry.isAdmin";
    }

    /// @inheritdoc IVersioned
    function version() external pure returns (string memory version_) {
        return "0.1.0";
    }
}
