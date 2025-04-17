// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "./IMigratable.sol";

/**
 * @title  Common interface for an XMTP Payload Broadcaster.
 * @notice A payload broadcaster is a contract that broadcasts payloads as events, where payloads have a min and max
 *         size, both of which can be updated from a parameter registry.
 */
interface IPayloadBroadcaster is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the minimum payload size is updated.
     * @param  size The new minimum payload size.
     * @dev    Will not be emitted if the new minimum is equal to the old minimum.
     */
    event MinPayloadSizeUpdated(uint256 indexed size);

    /**
     * @notice Emitted when the maximum payload size is updated.
     * @param  size The new maximum payload size.
     * @dev    Will not be emitted if the new maximum is equal to the old maximum.
     */
    event MaxPayloadSizeUpdated(uint256 indexed size);

    /**
     * @notice Emitted when the pause status is updated.
     * @param  paused The new pause status.
     */
    event PauseStatusUpdated(bool indexed paused);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the payload size is invalid.
    error InvalidPayloadSize(uint256 actualSize_, uint256 minSize_, uint256 maxSize_);

    /// @notice Thrown when the maximum payload size is invalid.
    error InvalidMaxPayloadSize();

    /// @notice Thrown when the minimum payload size is invalid.
    error InvalidMinPayloadSize();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Thrown when some pauseable function is called when the payload broadcaster is paused.
    error Paused();

    /* ============ Initialization ============ */

    /// @notice Initializes the contract.
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Updates the minimum payload size.
     * @dev    Ensures the new minimum is less than the maximum.
     * @dev    Ensures the new minimum is not equal to the old minimum.
     */
    function updateMinPayloadSize() external;

    /**
     * @notice Updates the maximum payload size.
     * @dev    Ensures the new maximum is greater than the minimum.
     * @dev    Ensures the new maximum is not equal to the old maximum.
     */
    function updateMaxPayloadSize() external;

    /**
     * @notice Updates the pause status.
     * @dev    Ensures the new pause status is not equal to the old pause status.
     */
    function updatePauseStatus() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the minimum payload size.
    function minPayloadSizeParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key used to fetch the maximum payload size.
    function maxPayloadSizeParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key used to fetch the paused status.
    function pausedParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice Minimum valid payload size (in bytes).
    function minPayloadSize() external view returns (uint256 size_);

    /// @notice Maximum valid payload size (in bytes).
    function maxPayloadSize() external view returns (uint256 size_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);
}
