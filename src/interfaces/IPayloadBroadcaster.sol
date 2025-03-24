// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "./IMigratable.sol";

interface IPayloadBroadcaster is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the minimum payload size is set.
     * @param  size The new minimum payload size.
     */
    event MinPayloadSizeUpdated(uint256 indexed size);

    /**
     * @notice Emitted when the maximum payload size is set.
     * @param  size The new maximum payload size.
     */
    event MaxPayloadSizeUpdated(uint256 indexed size);

    /**
     * @notice Emitted when the pause status is set.
     * @param  paused The new pause status.
     */
    event PauseStatusUpdated(bool indexed paused);

    /* ============ Custom Errors ============ */

    error ZeroRegistryAddress();

    error InvalidPayloadSize(uint256 actualSize_, uint256 minSize_, uint256 maxSize_);

    error InvalidMaxPayloadSize();

    error InvalidMinPayloadSize();

    error NoChange();

    error ZeroImplementationAddress();

    error Paused();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Updates the minimum payload size.
     * @dev    Ensures the new minimum is less than the maximum.
     */
    function updateMinPayloadSize() external;

    /**
     * @notice Updates the maximum payload size.
     * @dev    Ensures the new maximum is greater than the minimum.
     */
    function updateMaxPayloadSize() external;

    /**
     * @notice Updates the pause status.
     */
    function updatePauseStatus() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The absolute minimum valid payload size (in bytes).
    function ABSOLUTE_MIN_PAYLOAD_SIZE() external pure returns (uint256 size_);

    /// @notice The absolute maximum valid payload size (in bytes).
    function ABSOLUTE_MAX_PAYLOAD_SIZE() external pure returns (uint256 size_);

    /// @notice The parameter registry key for the minimum payload size.
    function minPayloadSizeParameterKey() external pure returns (bytes memory key_);

    /// @notice The key for the maximum payload size.
    function maxPayloadSizeParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the paused status.
    function pausedParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function registry() external view returns (address registry_);

    /// @notice Minimum valid payload size (in bytes).
    function minPayloadSize() external view returns (uint256 size_);

    /// @notice Maximum valid payload size (in bytes).
    function maxPayloadSize() external view returns (uint256 size_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);
}
