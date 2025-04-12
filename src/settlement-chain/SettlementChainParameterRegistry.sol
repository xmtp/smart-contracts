// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ISettlementChainParameterRegistry } from "./interfaces/ISettlementChainParameterRegistry.sol";
import { IParameterRegistry } from "../abstract/interfaces/IParameterRegistry.sol";

import { ParameterRegistry } from "../abstract/ParameterRegistry.sol";

contract SettlementChainParameterRegistry is ISettlementChainParameterRegistry, ParameterRegistry {
    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IParameterRegistry
    function migratorParameterKey()
        public
        pure
        override(IParameterRegistry, ParameterRegistry)
        returns (bytes memory key_)
    {
        return "xmtp.scpr.migrator";
    }

    /// @inheritdoc IParameterRegistry
    function adminParameterKey()
        public
        pure
        override(IParameterRegistry, ParameterRegistry)
        returns (bytes memory key_)
    {
        return "xmtp.scpr.isAdmin";
    }
}
