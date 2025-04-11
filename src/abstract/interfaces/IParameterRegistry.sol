// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "./IMigratable.sol";

interface IParameterRegistry is IMigratable {
    /* ============ Events ============ */

    event ParameterSet(bytes indexed key, bytes[] keyChain_, bytes32 indexed value);

    /* ============ Custom Errors ============ */

    error NotAdmin();

    error NoKeyChains();

    error ArrayLengthMismatch();

    error EmptyKeyChain();

    /* ============ Initialization ============ */

    function initialize(address[] calldata admins_) external;

    /* ============ Interactive Functions ============ */

    function set(bytes[][] calldata keyChains_, bytes32[] calldata values_) external;

    function set(bytes[] calldata keyChain_, bytes32 value_) external;

    /* ============ View/Pure Functions ============ */

    function migratorParameterKey() external pure returns (bytes memory key_);

    function adminParameterKey() external pure returns (bytes memory key_);

    function isAdmin(address account_) external view returns (bool isAdmin_);

    function get(bytes[][] calldata keyChains_) external view returns (bytes32[] memory values_);

    function get(bytes[] calldata keyChain_) external view returns (bytes32 value_);

    function get(bytes calldata key_) external view returns (bytes32 value_);
}
