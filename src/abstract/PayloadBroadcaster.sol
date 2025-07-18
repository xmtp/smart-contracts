// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IMigratable } from "./interfaces/IMigratable.sol";
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
        uint32 minPayloadSize;
        uint32 maxPayloadSize;
        uint64 sequenceId;
        bool paused;
        address payloadBootstrapper;
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
    function initialize() public virtual initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function updateMinPayloadSize() external {
        uint32 minPayloadSize_ = RegistryParameters.getUint32Parameter(parameterRegistry, minPayloadSizeParameterKey());

        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (minPayloadSize_ > $.maxPayloadSize) revert InvalidMinPayloadSize();
        if (minPayloadSize_ == $.minPayloadSize) revert NoChange();

        emit MinPayloadSizeUpdated($.minPayloadSize = minPayloadSize_);
    }

    /// @inheritdoc IPayloadBroadcaster
    function updateMaxPayloadSize() external {
        uint32 maxPayloadSize_ = RegistryParameters.getUint32Parameter(parameterRegistry, maxPayloadSizeParameterKey());

        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (maxPayloadSize_ < $.minPayloadSize) revert InvalidMaxPayloadSize();
        if (maxPayloadSize_ == $.maxPayloadSize) revert NoChange();

        emit MaxPayloadSizeUpdated($.maxPayloadSize = maxPayloadSize_);
    }

    /// @inheritdoc IPayloadBroadcaster
    function updatePauseStatus() external {
        bool paused_ = RegistryParameters.getBoolParameter(parameterRegistry, pausedParameterKey());
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (paused_ == $.paused) revert NoChange();

        emit PauseStatusUpdated($.paused = paused_);
    }

    /// @inheritdoc IPayloadBroadcaster
    function updatePayloadBootstrapper() external {
        address payloadBootstrapper_ = RegistryParameters.getAddressParameter(
            parameterRegistry,
            payloadBootstrapperParameterKey()
        );

        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (payloadBootstrapper_ == $.payloadBootstrapper) revert NoChange();

        emit PayloadBootstrapperUpdated($.payloadBootstrapper = payloadBootstrapper_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayloadBroadcaster
    function minPayloadSizeParameterKey() public pure virtual returns (string memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSizeParameterKey() public pure virtual returns (string memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function migratorParameterKey() public pure virtual returns (string memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function pausedParameterKey() public pure virtual returns (string memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function payloadBootstrapperParameterKey() public pure virtual returns (string memory key_);

    /// @inheritdoc IPayloadBroadcaster
    function minPayloadSize() external view returns (uint32 size_) {
        return _getPayloadBroadcasterStorage().minPayloadSize;
    }

    /// @inheritdoc IPayloadBroadcaster
    function maxPayloadSize() external view returns (uint32 size_) {
        return _getPayloadBroadcasterStorage().maxPayloadSize;
    }

    /// @inheritdoc IPayloadBroadcaster
    function paused() external view returns (bool paused_) {
        return _getPayloadBroadcasterStorage().paused;
    }

    /// @inheritdoc IPayloadBroadcaster
    function payloadBootstrapper() external view returns (address payloadBootstrapper_) {
        return _getPayloadBroadcasterStorage().payloadBootstrapper;
    }

    /* ============ Internal View/Pure Functions ============ */

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfPaused() internal view {
        if (_getPayloadBroadcasterStorage().paused) revert Paused();
    }

    function _revertIfNotPaused() internal view {
        if (!_getPayloadBroadcasterStorage().paused) revert NotPaused();
    }

    function _revertIfInvalidPayloadSize(uint256 payloadSize_) internal view {
        PayloadBroadcasterStorage storage $ = _getPayloadBroadcasterStorage();

        if (payloadSize_ < $.minPayloadSize || payloadSize_ > $.maxPayloadSize) {
            revert InvalidPayloadSize(payloadSize_, $.minPayloadSize, $.maxPayloadSize);
        }
    }

    function _revertIfNotPayloadBootstrapper() internal view {
        if (_getPayloadBroadcasterStorage().payloadBootstrapper != msg.sender) revert NotPayloadBootstrapper();
    }
}
