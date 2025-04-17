// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IParameterRegistry } from "../../abstract/interfaces/IParameterRegistry.sol";

/**
 * @title  Interface for a Settlement Chain Parameter Registry.
 * @notice A SettlementChainParameterRegistry is a parameter registry used by the protocol contracts on the settlement
 *         chain.
 */
interface ISettlementChainParameterRegistry is IParameterRegistry {}
