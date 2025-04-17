// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

interface IRateRegistry is IMigratable {
    /* ============ Structs ============ */

    /**
     * @notice The Rates struct holds the fees and the start time of the rates.
     * @param  messageFee          The message fee.
     * @param  storageFee          The storage fee.
     * @param  congestionFee       The congestion fee.
     * @param  targetRatePerMinute The target rate per minute.
     * @param  startTime           The start time when the rates became effective.
     */
    struct Rates {
        uint64 messageFee;
        uint64 storageFee;
        uint64 congestionFee;
        uint64 targetRatePerMinute;
        uint64 startTime;
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when the rates are updated.
     * @param  messageFee          The message fee.
     * @param  storageFee          The storage fee.
     * @param  congestionFee       The congestion fee.
     * @param  targetRatePerMinute The target rate per minute.
     * @param  startTime           The start time when the rates become effective.
     */
    event RatesUpdated(
        uint64 messageFee,
        uint64 storageFee,
        uint64 congestionFee,
        uint64 targetRatePerMinute,
        uint64 startTime
    );

    /* ============ Custom Errors ============ */

    /// @notice Error thrown when the parameter registry address is being set to 0x0.
    error ZeroParameterRegistryAddress();

    /// @notice Thrown when the `fromIndex` is out of range.
    error FromIndexOutOfRange();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Updates the rates.
     */
    function updateRates() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The page size for the rates.
    // slither-disable-next-line naming-convention
    function PAGE_SIZE() external pure returns (uint256 pageSize_);

    /**
     * @notice Returns a slice of the Rates list for pagination.
     * @param  fromIndex_ Index from which to start (must be < allRates.length).
     * @return rates_     The subset of Rates.
     * @return hasMore_   True if there are more items beyond this slice.
     */
    function getRates(uint256 fromIndex_) external view returns (Rates[] memory rates_, bool hasMore_);

    /// @notice The total number of Rates stored.
    function getRatesCount() external view returns (uint256 count_);

    /// @notice The parameter registry key for the message fee.
    function messageFeeParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the storage fee.
    function storageFeeParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the congestion fee.
    function congestionFeeParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the rate per minute.
    function targetRatePerMinuteParameterKey() external pure returns (bytes memory key_);

    /// @notice The parameter registry key for the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);
}
