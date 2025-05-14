// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "./interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IPayloadBroadcaster } from "./interfaces/IPayloadBroadcaster.sol";

import { Migratable } from "./Migratable.sol";

/**
 * @title  Common abstract implementation for an XMTP Payload Broadcaster.
 * @notice A payload broadcaster is a contract that broadcasts payloads as events, where payloads have a min and max
 *         size, both of which can be updated from a parameter registry.
 */
abstract contract PayloadBroadcaster is IPayloadBroadcaster, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IPayloadBroadcaster
    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.PayloadBroadcaster
     * @notice The UUPS storage for the payload broadcaster.
     * @param  minPayloadSize The minimum payload size.
     * @param  maxPayloadSize The maximum payload size.
     * @param  sequenceId     A sequence ID for uniquely ordering payloads (should be monotonically increasing).
     * @param  paused         The paused status.
     */
    struct PayloadBroadcasterStorage {
        uint256 minPayloadSize;
        uint256 maxPayloadSize;
        uint64 sequenceId;
        bool paused;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.PayloadBroadcaster")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PAYLOAD_BROADCASTER_STORAGE_LOCATION =
        0xeda186f2b85b2c197e0a3ff15dc0c5c16c74d00b5c7f432acaa215db84203b00;

    function _getPayloadBroadcasterStorage() internal pure returns (PayloadBroadcasterStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _PAYLOAD_BROADCASTER_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier whenNotPaused() {
        _revertIfPaused();
        _;
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

    /// @inheritdoc IPayloadBroadcaster
    function initialize() public virtual initializer {
        // Since both the min and max start at 0, the max must be updated before the min, since the min can never be
        // set to be greater than the max.
        _updateMaxPayloadSize();
        _updateMinPayloadSize();
        _updatePauseStatus(); // The contract may start out paused, as needed.
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function updateMinPayloadSize() external {
        if (!_updateMinPayloadSize()) revert NoChange();
    }

    /// @inheritdoc IPayloadBroadcaster
    function updateMaxPayloadSize() external {
        if (!_updateMaxPayloadSize()) revert NoChange();
    }

    /// @inheritdoc IPayloadBroadcaster
    function updatePauseStatus() external {
        if (!_updatePauseStatus()) revert NoChange();
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function minPayloadSizeParameterKey() public pure virtual returns (bytes memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey() public pure virtual returns (bytes memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey() public pure virtual returns (bytes memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey() public pure virtual returns (bytes memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function minPayloadSize() external view returns (uint256 size_) {
        return _getPayloadBroadcasterStorage().minPayloadSize;
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSize() external view returns (uint256 size_) {
        return _getPayloadBroadcasterStorage().maxPayloadSize;
    }

    /// @inheritdoc IPayloadBroadcaster
    function paused() external view returns (bool paused_) {
        return _getPayloadBroadcasterStorage().paused;
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Sets the min payload size by fetching it from the parameter registry, returning whether i changed.
    function _updateMinPayloadSize() internal returns (bool changed_) {
        uint256 minPayloadSize_ = uint256(_getRegistryParameter(minPayloadSizeParameterKey()));
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (minPayloadSize_ > $.maxPayloadSize) revert InvalidMinPayloadSize();

        changed_ = minPayloadSize_ != $.minPayloadSize;

        emit MinPayloadSizeUpdated($.minPayloadSize = minPayloadSize_);
    }

    /// @dev Sets the max payload size by fetching it from the parameter registry, returning whether it changed.
    function _updateMaxPayloadSize() internal returns (bool changed_) {
        uint256 maxPayloadSize_ = uint256(_getRegistryParameter(maxPayloadSizeParameterKey()));
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (maxPayloadSize_ < $.minPayloadSize) revert InvalidMaxPayloadSize();

        changed_ = maxPayloadSize_ != $.maxPayloadSize;

        emit MaxPayloadSizeUpdated($.maxPayloadSize = maxPayloadSize_);
    }

    /// @dev Sets the paused status by fetching it from the parameter registry, returning whether it changed.
    function _updatePauseStatus() internal returns (bool changed_) {
        bool paused_ = _getRegistryParameter(pausedParameterKey()) != bytes32(0);
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        changed_ = paused_ != $.paused;

        emit PauseStatusUpdated($.paused = paused_);
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfPaused() internal view {
        if (_getPayloadBroadcasterStorage().paused) revert Paused();
    }

    function _revertIfInvalidPayloadSize(uint256 payloadSize_) internal view {
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (payloadSize_ < $.minPayloadSize || payloadSize_ > $.maxPayloadSize) {
            revert InvalidPayloadSize(payloadSize_, $.minPayloadSize, $.maxPayloadSize);
        }
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }
}
