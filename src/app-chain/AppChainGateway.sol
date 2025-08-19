// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { AddressAliasHelper } from "../libraries/AddressAliasHelper.sol";
import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IAppChainGateway } from "./interfaces/IAppChainGateway.sol";
import { IArbSysLike, ISettlementChainGatewayLike } from "./interfaces/External.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation for an App Chain Gateway.
 * @notice The AppChainGateway exposes the ability to receive parameters from the settlement chain gateway, and set
 *         them at the parameter registry on this same app chain. Currently, it is a receiver-only contract.
 */
contract AppChainGateway is IAppChainGateway, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    /// @dev The Arbitrum system precompile address.
    address internal constant _ARB_SYS = 0x0000000000000000000000000000000000000064; // address(100)

    /// @inheritdoc IAppChainGateway
    address public immutable parameterRegistry;

    /// @inheritdoc IAppChainGateway
    address public immutable settlementChainGateway;

    /// @inheritdoc IAppChainGateway
    address public immutable settlementChainGatewayAlias;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.AppChainGateway
     * @notice The UUPS storage for the app chain gateway.
     * @param  keyNonces A mapping of keys and their corresponding nonces, to track order of parameter receptions.
     */
    struct AppChainGatewayStorage {
        bool paused;
        mapping(string key => uint256 nonce) keyNonces;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.AppChainGateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _APP_CHAIN_GATEWAY_STORAGE_LOCATION =
        0xf7630100a9c96f7b07fb982ff1e6dad8abbb961bacff2e820fac4ea93b280300;

    function _getAppChainGatewayStorage() internal pure returns (AppChainGatewayStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _APP_CHAIN_GATEWAY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    /// @notice Modifier to ensure the caller is the settlement chain gateway (i.e. its L3 alias address).
    modifier onlySettlementChainGateway() {
        _revertIfNotSettlementChainGateway();
        _;
    }

    modifier whenNotPaused() {
        _revertIfPaused();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_      The address of the parameter registry.
     * @param  settlementChainGateway_ The address of the settlement chain gateway.
     * @dev    The parameter registry and settlement chain gateway must not be the zero address.
     * @dev    The parameter registry, settlement chain gateway, and the settlement chain gateway alias are immutable so
     *         that they are inlined in the contract code, and have minimal gas cost.
     */
    constructor(address parameterRegistry_, address settlementChainGateway_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(settlementChainGateway = settlementChainGateway_)) revert ZeroSettlementChainGateway();

        // Despite the `L1ToL2Alias` naming, this function is also used to get the L3 alias address of an L2 account.
        // Save gas at runtime by inlining the alias address as an immutable.
        settlementChainGatewayAlias = AddressAliasHelper.toAlias(settlementChainGateway_);

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IAppChainGateway
    function initialize() external initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IAppChainGateway
    function withdraw(address recipient_) external payable whenNotPaused {
        _withdraw(recipient_, ISettlementChainGatewayLike.receiveWithdrawal.selector);
    }

    /// @inheritdoc IAppChainGateway
    function withdrawIntoUnderlying(address recipient_) external payable whenNotPaused {
        _withdraw(recipient_, ISettlementChainGatewayLike.receiveWithdrawalIntoUnderlying.selector);
    }

    /// @inheritdoc IAppChainGateway
    function receiveDeposit(address recipient_) external payable {
        emit DepositReceived(recipient_, msg.value);

        // NOTE: When invoked via the settlement chain gateway retryable, `msg.value` is the bridged amount (less fees).
        //       This function is intentionally open; it will forward any attached value to the recipient.
        // slither-disable-next-line missing-zero-check
        (bool success_, ) = recipient_.call{ value: msg.value }("");

        if (!success_) revert TransferFailed();
    }

    /// @inheritdoc IAppChainGateway
    function receiveParameters(
        uint256 nonce_,
        string[] calldata keys_,
        bytes32[] calldata values_
    ) external onlySettlementChainGateway {
        AppChainGatewayStorage storage $ = _getAppChainGatewayStorage();

        emit ParametersReceived(nonce_, keys_);

        for (uint256 index_; index_ < keys_.length; ++index_) {
            string calldata key_ = keys_[index_];

            // Each key is checked against its nonce, and ignored if the nonce is lower than the stored nonce. This is
            // to prevent out-of-order parameter receptions. For example, if the settlement chain gateway sends key A
            // when it has a value of 10, and then again shortly after when it has a value of 5, the key cannot be set
            // out of order. Either the A=10 comes first, then the A=5, or the A=5 comes first, and the A=10 is ignored.
            if ($.keyNonces[key_] >= nonce_) continue;

            $.keyNonces[key_] = nonce_;

            RegistryParameters.setRegistryParameter(parameterRegistry, key_, values_[index_]);
        }
    }

    /// @inheritdoc IAppChainGateway
    function updatePauseStatus() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        bool paused_ = RegistryParameters.getBoolParameter(parameterRegistry, pausedParameterKey());
        AppChainGatewayStorage storage $ = _getAppChainGatewayStorage();

        if (paused_ == $.paused) revert NoChange();

        emit PauseStatusUpdated($.paused = paused_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IAppChainGateway
    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.appChainGateway.migrator";
    }

    /// @inheritdoc IAppChainGateway
    function pausedParameterKey() public pure returns (string memory key_) {
        return "xmtp.appChainGateway.paused";
    }

    /// @inheritdoc IAppChainGateway
    function paused() external view returns (bool paused_) {
        return _getAppChainGatewayStorage().paused;
    }

    /* ============ Internal Interactive Functions ============ */

    function _withdraw(address recipient_, bytes4 selector_) internal {
        if (_isZero(recipient_)) revert ZeroRecipient();
        if (msg.value == 0) revert ZeroWithdrawalAmount();

        uint256 messageId_ = IArbSysLike(_ARB_SYS).sendTxToL1{ value: msg.value }(
            settlementChainGateway,
            abi.encodeWithSelector(selector_, recipient_)
        );

        // slither-disable-next-line reentrancy-events
        emit Withdrawal(messageId_, recipient_, msg.value);
    }

    /* ============ Internal View/Pure Functions ============ */

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfNotSettlementChainGateway() internal view {
        if (msg.sender != settlementChainGatewayAlias) revert NotSettlementChainGateway();
    }

    function _revertIfPaused() internal view {
        if (_getAppChainGatewayStorage().paused) revert Paused();
    }
}
