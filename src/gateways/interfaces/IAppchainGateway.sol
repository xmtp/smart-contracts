// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAppchainGateway {
    /* ============ Structs ============ */

    /* ============ Events ============ */

    /* ============ Custom Errors ============ */

    error ZeroRegistryAddress();

    error ZeroSettlementGatewayAddress();

    error ZeroAdminAddress();

    error NotSettlementGateway();

    error NotAdmin();

    error ZeroImplementationAddress();

    /* ============ Initialization ============ */

    function initialize(address admin_) external;

    /* ============ Interactive Functions ============ */

    function receiveParameters(bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    /* ============ View/Pure Functions ============ */

    function admin() external view returns (address admin_);
}
