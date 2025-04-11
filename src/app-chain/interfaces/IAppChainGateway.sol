// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAppChainGateway {
    /* ============ Custom Errors ============ */

    event ParametersReceived(uint256 indexed nonce, bytes[][] keyChains);

    /* ============ Custom Errors ============ */

    error ZeroRegistryAddress();

    error ZeroSettlementChainGatewayAddress();

    error NotSettlementChainGateway();

    error EmptyKeyChain();

    /* ============ Initialization ============ */

    function initialize() external;

    /* ============ Interactive Functions ============ */

    function receiveParameters(uint256 nonce_, bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    /* ============ View/Pure Functions ============ */

    function migratorParameterKey() external pure returns (bytes memory key_);
}
