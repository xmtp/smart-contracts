// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAppChainGateway {
    /* ============ Custom Errors ============ */

    error ZeroRegistryAddress();

    error ZeroSettlementChainGatewayAddress();

    error NotSettlementChainGateway();

    /* ============ Initialization ============ */

    function initialize() external;

    /* ============ Interactive Functions ============ */

    function receiveParameters(bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    /* ============ View/Pure Functions ============ */

    function migratorParameterKey() external pure returns (bytes memory key_);
}
