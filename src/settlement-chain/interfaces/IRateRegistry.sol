// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IIdentified } from "../../abstract/interfaces/IIdentified.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Interface for the Rate Registry.
 * @notice This interface exposes functionality for updating the rates, tracking them historically.
 */
interface IRateRegistry is IMigratable, IIdentified, IRegistryParametersErrors {
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
     * @param  startTime           The start time of the rate.
     */
    event RatesUpdated(
        uint64 messageFee,
        uint64 storageFee,
        uint64 congestionFee,
        uint64 targetRatePerMinute,
        uint64 startTime
    );

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the query count is zero.
    error ZeroCount();

    /// @notice Thrown when the `fromIndex` is out of range.
    error FromIndexOutOfRange();

    /// @notice Thrown when the end index (as computed from the `fromIndex` and `count`) is out of range.
    error EndIndexOutOfRange();

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

    /**
     * @notice Returns a slice of the Rates list for pagination.
     * @param  fromIndex_ Index from which to start (must be < allRates.length).
     * @param  count_     The number of items to return.
     * @return rates_     The subset of Rates.
     */
    function getRates(uint256 fromIndex_, uint256 count_) external view returns (Rates[] memory rates_);

    /// @notice The total number of Rates stored.
    function getRatesCount() external view returns (uint256 count_);

    /// @notice The parameter registry key used to fetch the message fee.
    function messageFeeParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the storage fee.
    function storageFeeParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the congestion fee.
    function congestionFeeParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the target rate per minute.
    function targetRatePerMinuteParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the rates in effect after timestamp.
    function ratesInEffectAfterParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);
}
