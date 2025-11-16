// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ISettlementChainParameterRegistry } from "./interfaces/ISettlementChainParameterRegistry.sol";
import { IParameterRegistry } from "../abstract/interfaces/IParameterRegistry.sol";
import { IVersioned } from "../abstract/interfaces/IVersioned.sol";

import { ParameterRegistry } from "../abstract/ParameterRegistry.sol";

/**
 * @title  Implementation for a Settlement Chain Parameter Registry.
 * @notice A SettlementChainParameterRegistry is a parameter registry used by the protocol contracts on the settlement
 *         chain.
 */
contract SettlementChainParameterRegistry is ISettlementChainParameterRegistry, ParameterRegistry {
    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IParameterRegistry
    function migratorParameterKey()
        public
        pure
        override(IParameterRegistry, ParameterRegistry)
        returns (string memory key_)
    {
        return "xmtp.settlementChainParameterRegistry.migrator";
    }

    /// @inheritdoc IParameterRegistry
    function adminParameterKey()
        public
        pure
        override(IParameterRegistry, ParameterRegistry)
        returns (string memory key_)
    {
        return "xmtp.settlementChainParameterRegistry.isAdmin";
    }

    /// @inheritdoc IVersioned
    function version() external pure returns (string memory version_) {
        return "0.1.0";
    }
}
