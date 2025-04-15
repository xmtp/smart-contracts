// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

/**
 * @title  IAppChainGateway
 * @notice Interface for the AppChainGateway.
 */
interface IAppChainGateway is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when parameters are received from the settlement chain.
     * @param  nonce The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keys  The keys of the parameters.
     */
    event ParametersReceived(uint256 indexed nonce, bytes[] keys);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is zero.
    error ZeroParameterRegistryAddress();

    /// @notice Thrown when the settlement chain gateway address is zero.
    error ZeroSettlementChainGatewayAddress();

    /// @notice Thrown when the sender is not the settlement chain gateway.
    error NotSettlementChainGateway();

    /* ============ Initialization ============ */

    /// @notice Initializes the gateway.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Receives parameters from the settlement chain.
     * @param  nonce_  The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keys_   The keys of the parameters.
     * @param  values_ The values of the parameters.
     */
    function receiveParameters(uint256 nonce_, bytes[] calldata keys_, bytes32[] calldata values_) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the settlement chain gateway.
    function settlementChainGateway() external view returns (address settlementChainGateway_);

    /// @notice The alias address of the settlement chain gateway.
    function settlementChainGatewayAlias() external view returns (address settlementChainGatewayAlias_);

    /// @notice The parameter registry key of the migrator parameter.
    function migratorParameterKey() external pure returns (bytes memory key_);
}
