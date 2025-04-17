// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IRateRegistry } from "./interfaces/IRateRegistry.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: PAGE_SIZE should be a default, but overridden by the caller.
// TODO: Nodes should filter recent events to build rates array, without requiring contract to maintain it.
// TODO: Technically, the `startTime` in the `RatesUpdated` event is not needed, but it's kept for now.

contract RateRegistry is IRateRegistry, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IRateRegistry
    uint256 public constant PAGE_SIZE = 50; // Fixed page size for reading rates.

    /// @inheritdoc IRateRegistry
    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.RateRegistry
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
     * @notice Constructor for the PayerRegistry contract.
     * @param  parameterRegistry_ The address of the parameter registry.
     */
    constructor(address parameterRegistry_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistryAddress());
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IRateRegistry
    function initialize() public initializer {
        // TODO: If nothing to initialize, consider `_disableInitializers()` in constructor.
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IRateRegistry
    function updateRates() external {
        RateRegistryStorage storage $ = _getRateRegistryStorage();

        uint64 messageFee_ = _toUint64(_getRegistryParameter(messageFeeParameterKey()));
        uint64 storageFee_ = _toUint64(_getRegistryParameter(storageFeeParameterKey()));
        uint64 congestionFee_ = _toUint64(_getRegistryParameter(congestionFeeParameterKey()));
        uint64 targetRatePerMinute_ = _toUint64(_getRegistryParameter(targetRatePerMinuteParameterKey()));
        uint64 startTime_ = uint64(block.timestamp);

        _revertIfNoRateChange(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_);

        $.allRates.push(Rates(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_, startTime_));

        emit RatesUpdated(messageFee_, storageFee_, congestionFee_, targetRatePerMinute_, startTime_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IRateRegistry
    function messageFeeParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.rateRegistry.messageFee";
    }

    /// @inheritdoc IRateRegistry
    function storageFeeParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.rateRegistry.storageFee";
    }

    /// @inheritdoc IRateRegistry
    function congestionFeeParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.rateRegistry.congestionFee";
    }

    /// @inheritdoc IRateRegistry
    function targetRatePerMinuteParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.rateRegistry.targetRatePerMinute";
    }

    /// @inheritdoc IRateRegistry
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.rateRegistry.migrator";
    }

    /**
     * @dev    Returns a slice of the Rates list for pagination.
     * @param  fromIndex_ Index from which to start (must be < allRates.length).
     * @return rates_     The subset of Rates.
     * @return hasMore_   True if there are more items beyond this slice.
     */
    function getRates(uint256 fromIndex_) external view returns (Rates[] memory rates_, bool hasMore_) {
        RateRegistryStorage storage $ = _getRateRegistryStorage();

        // TODO: Fix unexpected behavior that an out of bounds query is not an error when the list is empty.
        if ($.allRates.length == 0 && fromIndex_ == 0) return (new Rates[](0), false);

        require(fromIndex_ < $.allRates.length, FromIndexOutOfRange());

        uint256 toIndex_ = _min(fromIndex_ + PAGE_SIZE, $.allRates.length);

        rates_ = new Rates[](toIndex_ - fromIndex_);

        for (uint256 i_; i_ < rates_.length; ++i_) {
            rates_[i_] = $.allRates[fromIndex_ + i_];
        }

        hasMore_ = toIndex_ < $.allRates.length;
    }

    /**
     * @dev Returns the total number of Rates stored.
     */
    function getRatesCount() external view returns (uint256 count_) {
        return _getRateRegistryStorage().allRates.length;
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }

    /// @dev Returns the minimum of two numbers.
    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        return a_ < b_ ? a_ : b_;
    }

    function _toUint64(bytes32 value_) internal pure returns (uint64 output_) {
        // slither-disable-next-line assembly
        assembly {
            output_ := value_
        }
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
