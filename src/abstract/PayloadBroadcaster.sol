// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "./interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IPayloadBroadcaster } from "./interfaces/IPayloadBroadcaster.sol";

import { Migratable } from "./Migratable.sol";

/// @title XMTP Abstract Payload Broadcaster Contract
abstract contract PayloadBroadcaster is IPayloadBroadcaster, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IPayloadBroadcaster
    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.PayloadBroadcaster
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
     * @notice Constructor for immutables.
     * @param  parameterRegistry_ The address of the parameter registry.
     */
    constructor(address parameterRegistry_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistryAddress());
        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IPayloadBroadcaster
    function initialize() public virtual initializer {
        _updateMaxPayloadSize();
        _updateMinPayloadSize();
        _updatePauseStatus();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function updateMinPayloadSize() external {
        require(_updateMinPayloadSize(), NoChange());
    }

    /// @inheritdoc IPayloadBroadcaster
    function updateMaxPayloadSize() external {
        require(_updateMaxPayloadSize(), NoChange());
    }

    /// @inheritdoc IPayloadBroadcaster
    function updatePauseStatus() external {
        require(_updatePauseStatus(), NoChange());
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(address(uint160(uint256(_getRegistryParameter(migratorParameterKey())))));
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

    function _updateMinPayloadSize() internal returns (bool changed_) {
        uint256 minPayloadSize_ = uint256(_getRegistryParameter(minPayloadSizeParameterKey()));
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        require(minPayloadSize_ <= $.maxPayloadSize, InvalidMinPayloadSize());

        changed_ = minPayloadSize_ != $.minPayloadSize;

        emit MinPayloadSizeUpdated($.minPayloadSize = minPayloadSize_);
    }

    function _updateMaxPayloadSize() internal returns (bool changed_) {
        uint256 maxPayloadSize_ = uint256(_getRegistryParameter(maxPayloadSizeParameterKey()));
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        require(maxPayloadSize_ >= $.minPayloadSize, InvalidMaxPayloadSize());

        changed_ = maxPayloadSize_ != $.maxPayloadSize;

        emit MaxPayloadSizeUpdated($.maxPayloadSize = maxPayloadSize_);
    }

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

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }

    function _revertIfPaused() internal view {
        require(!_getPayloadBroadcasterStorage().paused, Paused());
    }

    function _revertIfInvalidPayloadSize(uint256 payloadSize_) internal view {
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (payloadSize_ < $.minPayloadSize || payloadSize_ > $.maxPayloadSize) {
            revert InvalidPayloadSize(payloadSize_, $.minPayloadSize, $.maxPayloadSize);
        }
    }
}
