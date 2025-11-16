// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IVersioned } from "../abstract/interfaces/IVersioned.sol";
import { IRateRegistry } from "./interfaces/IRateRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: Nodes should filter recent events to build rates array, without requiring contract to maintain it.

/**
 * @title  Implementation of the Rate Registry.
 * @notice This contract handles functionality for updating the rates, tracking them historically.
 */
contract RateRegistry is IRateRegistry, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IRateRegistry
    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.RateRegistry
     * @notice The UUPS storage for the rate registry.
     * @param  allRates The array of all historical rates.
     */
    struct RateRegistryStorage {
        Rates[] allRates; // All Rates appended here.
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.RateRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _RATE_REGISTRY_STORAGE_LOCATION =
        0x988e236e2caf5758fdf811320ba1d2fca453cb71bd6049ebba876b68af505000;

    function _getRateRegistryStorage() internal pure returns (RateRegistryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _RATE_REGISTRY_STORAGE_LOCATION
        }
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @dev    The parameter registry must not be the zero address.
     * @dev    The parameter registry is immutable so that it is inlined in the contract code, and has minimal gas cost.
     */
    constructor(address parameterRegistry_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IRateRegistry
    function initialize() public initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IRateRegistry
    function updateRates() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        RateRegistryStorage storage $ = _getRateRegistryStorage();

        uint64 messageFee_ = RegistryParameters.getUint64Parameter(parameterRegistry, messageFeeParameterKey());
        uint64 storageFee_ = RegistryParameters.getUint64Parameter(parameterRegistry, storageFeeParameterKey());
        uint64 congestionFee_ = RegistryParameters.getUint64Parameter(parameterRegistry, congestionFeeParameterKey());

        uint64 targetRatePerMinute_ = RegistryParameters.getUint64Parameter(
            parameterRegistry,
            targetRatePerMinuteParameterKey()
        );

        _revertIfNoRateChange(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_);

        uint64 startTime_ = uint64(block.timestamp);

        $.allRates.push(Rates(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_, startTime_));

        emit RatesUpdated(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IRateRegistry
    function messageFeeParameterKey() public pure returns (string memory key_) {
        return "xmtp.rateRegistry.messageFee";
    }

    /// @inheritdoc IRateRegistry
    function storageFeeParameterKey() public pure returns (string memory key_) {
        return "xmtp.rateRegistry.storageFee";
    }

    /// @inheritdoc IRateRegistry
    function congestionFeeParameterKey() public pure returns (string memory key_) {
        return "xmtp.rateRegistry.congestionFee";
    }

    /// @inheritdoc IRateRegistry
    function targetRatePerMinuteParameterKey() public pure returns (string memory key_) {
        return "xmtp.rateRegistry.targetRatePerMinute";
    }

    /// @inheritdoc IRateRegistry
    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.rateRegistry.migrator";
    }

    /// @inheritdoc IRateRegistry
    function getRates(uint256 fromIndex_, uint256 count_) external view returns (Rates[] memory rates_) {
        if (count_ == 0) revert ZeroCount();

        RateRegistryStorage storage $ = _getRateRegistryStorage();

        if (fromIndex_ >= $.allRates.length) revert FromIndexOutOfRange();
        if (fromIndex_ + count_ > $.allRates.length) revert EndIndexOutOfRange();

        rates_ = new Rates[](count_);

        for (uint256 index_; index_ < count_; ++index_) {
            rates_[index_] = $.allRates[fromIndex_ + index_];
        }
    }

    /// @inheritdoc IRateRegistry
    function getRatesCount() external view returns (uint256 count_) {
        return _getRateRegistryStorage().allRates.length;
    }

    /// @inheritdoc IVersioned
    function version() external pure returns (string memory version_) {
        return "0.1.0";
    }

    /* ============ Internal View/Pure Functions ============ */

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    /// @dev Reverts if none of the rates have changed.
    function _revertIfNoRateChange(
        uint64 messageFee_,
        uint64 storageFee_,
        uint64 congestionFee_,
        uint64 targetRatePerMinute_
    ) internal view {
        RateRegistryStorage storage $ = _getRateRegistryStorage();

        if ($.allRates.length == 0) return;

        Rates memory rates_ = $.allRates[$.allRates.length - 1];

        if (
            rates_.messageFee == messageFee_ &&
            rates_.storageFee == storageFee_ &&
            rates_.congestionFee == congestionFee_ &&
            rates_.targetRatePerMinute == targetRatePerMinute_
        ) {
            revert NoChange();
        }
    }
}
