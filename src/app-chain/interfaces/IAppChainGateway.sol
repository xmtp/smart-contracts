// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Interface for an App Chain Gateway.
 * @notice The AppChainGateway exposes the ability to receive parameters from the settlement chain gateway.
 */
interface IAppChainGateway is IMigratable, IRegistryParametersErrors {
    /* ============ Events ============ */

    /**
     * @notice Emitted when parameters are received from the settlement chain.
     * @param  nonce The nonce of the parameter transmission (to prevent out-of-sequence parameter updates).
     * @param  keys  The keys of the parameters.
     * @dev    The `values` are not emitted, as they are not relevant to indexing this contract, and will be emitted
     *         by the app chain parameter registry.
     */
    event ParametersReceived(uint256 indexed nonce, bytes[] keys);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the settlement chain gateway address is zero (i.e. address(0)).
    error ZeroSettlementChainGateway();

    /// @notice Thrown when the caller is not the settlement chain gateway (i.e. its L3 alias address).
    error NotSettlementChainGateway();

    /* ============ Initialization ============ */

    /// @notice Initializes the parameter registry, as used by a proxy contract.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Receives parameters from the settlement chain.
     * @param  nonce_  The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keys_   The keys of the parameters.
     * @param  values_ The values of each parameter.
     * @dev    The caller must be the settlement chain gateway's L3 alias address.
     */
    function receiveParameters(uint256 nonce_, bytes[] calldata keys_, bytes32[] calldata values_) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the settlement chain gateway.
    function settlementChainGateway() external view returns (address settlementChainGateway_);

    /**
     * @notice The L3 alias address of the settlement chain gateway (i.e. the expected caller of the `receiveParameters`
     *         function).
     */
    function settlementChainGatewayAlias() external view returns (address settlementChainGatewayAlias_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);
}
