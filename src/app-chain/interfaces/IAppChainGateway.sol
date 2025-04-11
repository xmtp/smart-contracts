// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  IAppChainGateway
 * @notice Interface for the AppChainGateway.
 */
interface IAppChainGateway {
    /* ============ Events ============ */

    /**
     * @notice Emitted when parameters are received from the settlement chain.
     * @param  nonce     The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keyChains The key chains of the parameters.
     */
    event ParametersReceived(uint256 indexed nonce, bytes[][] keyChains);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the registry address is zero.
    error ZeroRegistryAddress();

    /// @notice Thrown when the settlement chain gateway address is zero.
    error ZeroSettlementChainGatewayAddress();

    /// @notice Thrown when the sender is not the settlement chain gateway.
    error NotSettlementChainGateway();

    /// @notice Thrown when the key chain is empty.
    error EmptyKeyChain();

    /* ============ Initialization ============ */

    /// @notice Initializes the gateway.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Receives parameters from the settlement chain.
     * @param  nonce_     The nonce of the parameter transmission (to prevent out-of-sequence resets).
     * @param  keyChains_ The key chains of the parameters.
     * @param  values_    The values of the parameters.
     */
    function receiveParameters(uint256 nonce_, bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The address of the registry.
    function registry() external view returns (address registry_);

    /// @notice The address of the settlement chain gateway.
    function settlementChainGateway() external view returns (address settlementChainGateway_);

    /// @notice The alias address of the settlement chain gateway.
    function settlementChainGatewayAlias() external view returns (address settlementChainGatewayAlias_);

    /// @notice The parameter registry key of the migrator parameter.
    function migratorParameterKey() external pure returns (bytes memory key_);
}
