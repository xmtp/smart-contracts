// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { IDepositSplitter } from "./interfaces/IDepositSplitter.sol";

import {
    IERC20Like,
    IFeeTokenLike,
    IPayerRegistryLike,
    IPermitErc20Like,
    ISettlementChainGatewayLike
} from "./interfaces/External.sol";

/**
 * @title  Deposit Splitter for payer funding convenience.
 * @notice This contract handles functionality for splitting deposits between the Payer Registry and App Chain.
 */
contract DepositSplitter is IDepositSplitter {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IDepositSplitter
    address public immutable feeToken;

    /// @inheritdoc IDepositSplitter
    address public immutable payerRegistry;

    /// @inheritdoc IDepositSplitter
    address public immutable settlementChainGateway;

    /// @inheritdoc IDepositSplitter
    uint256 public immutable appChainId;

    /// @dev The address of the token underlying the fee token.
    address internal immutable _underlyingFeeToken;

    /* ============ Constructor ============ */

    constructor(address feeToken_, address payerRegistry_, address settlementChainGateway_, uint256 appChainId_) {
        if (_isZero(feeToken = feeToken_)) revert ZeroFeeToken();
        if (_isZero(payerRegistry = payerRegistry_)) revert ZeroPayerRegistry();
        if (_isZero(settlementChainGateway = settlementChainGateway_)) revert ZeroSettlementChainGateway();

        if ((appChainId = appChainId_) == 0) revert ZeroAppChainId();

        _underlyingFeeToken = IFeeTokenLike(feeToken_).underlying();

        IERC20Like(feeToken_).approve(payerRegistry_, type(uint256).max);
        IERC20Like(feeToken_).approve(settlementChainGateway_, type(uint256).max);
    }

    function deposit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_
    ) external {
        _depositFeeToken(
            payer_,
            payerRegistryAmount_,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    function depositWithPermit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither the permit use nor `_depositFeeToken` can result in a reentrancy.
        _usePermit(feeToken, payerRegistryAmount_ + appChainAmount_, deadline_, v_, r_, s_);

        _depositFeeToken(
            payer_,
            payerRegistryAmount_,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    function depositFromUnderlying(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_
    ) external {
        _depositFromUnderlying(
            payer_,
            payerRegistryAmount_,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    function depositFromUnderlyingWithPermit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        // NOTE: There is no issue if the underlying fee token permit use results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy. Further, the permit must be used before being
        //       able to pull any underlying fee tokens from the caller.
        _usePermit(_underlyingFeeToken, payerRegistryAmount_ + appChainAmount_, deadline_, v_, r_, s_);

        _depositFromUnderlying(
            payer_,
            payerRegistryAmount_,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Transfers `amount_` of fee tokens from the caller to this contract, then performs both deposits.
    function _depositFeeToken(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_
    ) internal {
        // NOTE: No need for safe library here as the fee token is a first party contract with expected behavior.
        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IERC20Like(feeToken).transferFrom` nor `_deposit` can result in a reentrancy.
        // slither-disable-next-line unchecked-transfer
        IERC20Like(feeToken).transferFrom(msg.sender, address(this), payerRegistryAmount_ + appChainAmount_);

        _deposit(
            payer_,
            payerRegistryAmount_,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    /// @dev Transfers `amount_` of fee tokens from the caller to this contract, then performs both deposits.
    function _depositFromUnderlying(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_
    ) internal {
        // NOTE: There is no issue if the underlying fee token transfer results in a reentrancy, as the rest of the
        //       deposit flow will proceed normally after the reentrancy.
        SafeTransferLib.safeTransferFrom(
            _underlyingFeeToken,
            msg.sender,
            address(this),
            payerRegistryAmount_ + appChainAmount_
        );

        // NOTE: Since the fee token is a first party contract with expected behavior, no need to adhere to CEI here as
        //       neither `IFeeTokenLike(feeToken).deposit` nor `_deposit` can result in a reentrancy.
        IFeeTokenLike(feeToken).deposit(payerRegistryAmount_ + appChainAmount_);

        _deposit(
            payer_,
            payerRegistryAmount_,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    /// @dev Satisfies both deposits.
    function _deposit(
        address payer_,
        uint96 payerRegistryAmount_,
        address appChainRecipient_,
        uint96 appChainAmount_,
        uint256 appChainGasLimit_,
        uint256 appChainGasPrice_
    ) internal {
        IPayerRegistryLike(payerRegistry).deposit(payer_, payerRegistryAmount_);

        ISettlementChainGatewayLike(settlementChainGateway).deposit(
            appChainId,
            appChainRecipient_,
            appChainAmount_,
            appChainGasLimit_,
            appChainGasPrice_
        );
    }

    /**
     * @dev Uses a permit to approve the deposit of `amount_` of `token_` from the caller to this contract.
     * @dev Silently ignore a failing permit, as it may indicate that the permit was already used and/or the allowance
     *      has already been approved.
     */
    function _usePermit(address token_, uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) internal {
        // Ignore return value, as the permit may have already been used, and the allowance already approved.
        // slither-disable-next-line unchecked-lowlevel
        address(token_).call(
            abi.encodeWithSelector(
                IPermitErc20Like.permit.selector,
                msg.sender,
                address(this),
                amount_,
                deadline_,
                v_,
                r_,
                s_
            )
        );
    }

    /* ============ Internal View/Pure Functions ============ */

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }
}
