// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC20Like {
    function approve(address spender_, uint256 amount_) external returns (bool success_);

    function balanceOf(address account_) external view returns (uint256 balance_);
}

interface IERC20InboxLike {
    /// @dev event emitted when a inbox message is added to the Bridge's delayed accumulator
    event InboxMessageDelivered(uint256 indexed messageNum_, bytes data_);
}

interface IBridgeLike {
    event MessageDelivered(
        uint256 indexed messageIndex_,
        bytes32 indexed beforeInboxAcc_,
        address inbox_,
        uint8 kind_,
        address sender_,
        bytes32 messageDataHash_,
        uint256 baseFeeL1_,
        uint64 timestamp_
    );
}

interface IArbRetryableTxPrecompileLike {
    function submitRetryable(
        bytes32 requestId_,
        uint256 l1BaseFee_,
        uint256 deposit_,
        uint256 callValue_,
        uint256 gasFeeCap_,
        uint64 gasLimit_,
        uint256 maxSubmissionFee_,
        address feeRefundAddress_,
        address beneficiary_,
        address retryTo_,
        bytes calldata retryData_
    ) external;
}
