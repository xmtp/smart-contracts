// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// TODO: `calculateRetryableSubmissionFee` might actually be part of the counterpart inbox. Investigate.

/**
 * @title  Subset interface for ERC20 tokens.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IERC20Like {
    function balanceOf(address account) external view returns (uint256 balance);
}

/**
 * @title  Subset interface for Arbitrum ERC20-based Inbox.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IERC20InboxLike {
    /// @notice Sends a contract transaction to the L2 inbox, with a single-try execution on the L3.
    function sendContractTransaction(
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        address to_,
        uint256 value_,
        bytes calldata data_
    ) external returns (uint256 messageNumber_);

    /**
     * @notice Put a message in the L2 inbox that can be re-executed for some fixed amount of time if it reverts.
     * @dev    All tokenTotalFeeAmount will be deposited to callValueRefundAddress on L2.
     * @dev    Gas limit and maxFeePerGas should not be set to 1 as that is used to trigger the RetryableData error
     * @dev    In case of native token having non-18 decimals: tokenTotalFeeAmount is denominated in native token's
     *         decimals. All other value params - l2CallValue, maxSubmissionCost and maxFeePerGas are denominated in
     *         child chain's native 18 decimals.
     * @param  to_                     Destination L2 contract address.
     * @param  l2CallValue_            Call value for retryable L2 message.
     * @param  maxSubmissionCost_      Max gas deducted from user's L2 balance to cover base submission fee.
     * @param  excessFeeRefundAddress_ The address which receives the difference between execution fee paid and the
     *                                 actual execution cost. In case this address is a contract, funds will be received
     *                                 in its alias on L2.
     * @param  callValueRefundAddress_ L2 call value gets credited here on L2 if retryable txn times out or gets
     *                                 cancelled. In case this address is a contract, funds will be received in its
     *                                 alias on L2.
     * @param  gasLimit_               Max gas deducted from user's L2 balance to cover L2 execution. Should not be
     *                                 set to 1 (magic value used to trigger the RetryableData error).
     * @param  maxFeePerGas_           Price bid for L2 execution. Should not be set to 1 (magic value used to trigger
     *                                 the RetryableData error).
     * @param  tokenTotalFeeAmount_    The amount of fees to be deposited in native token to cover for retryable ticket
     *                                 cost.
     * @param  data_                   ABI encoded data of L2 message.
     * @return messageNumber_          The message number of the retryable transaction.
     */
    function createRetryableTicket(
        address to_,
        uint256 l2CallValue_,
        uint256 maxSubmissionCost_,
        address excessFeeRefundAddress_,
        address callValueRefundAddress_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 tokenTotalFeeAmount_,
        bytes calldata data_
    ) external returns (uint256 messageNumber_);

    /// @notice Deposits an ERC20 token into the L2 inbox, to be sent to the L3 where it is the gas token of that chain.
    function depositERC20(uint256 amount_) external returns (uint256 messageNumber_);

    /// @notice Calculates the submission fee for a retryable ticket.
    function calculateRetryableSubmissionFee(
        uint256 dataLength_,
        uint256 baseFee_
    ) external view returns (uint256 submissionFee_);
}

/**
 * @title  Subset interface for an AppChainGateway.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IAppChainGatewayLike {
    function receiveParameters(uint256 nonce_, bytes[] calldata keys_, bytes32[] calldata values_) external;
}

/**
 * @title  Subset interface for a NodeRegistry.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface INodeRegistryLike {
    function canonicalNodesCount() external view returns (uint8 canonicalNodesCount_);

    function getIsCanonicalNode(uint32 nodeId_) external view returns (bool isCanonicalNode_);

    function getSigner(uint32 nodeId_) external view returns (address signer_);

    function ownerOf(uint256 nodeId_) external view returns (address owner_);
}

/**
 * @title  Subset interface for a PayerRegistry.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IPayerRegistryLike {
    struct PayerFee {
        address payer;
        uint96 fee;
    }

    function settleUsage(PayerFee[] calldata payerFees_) external returns (uint96 feesSettled_);

    function sendExcessToFeeDistributor() external returns (uint96 excess_);
}

/**
 * @title  Subset interface for a PayerReportManager.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IPayerReportManagerLike {
    struct PayerReport {
        uint64 startSequenceId;
        uint64 endSequenceId;
        uint96 feesSettled;
        uint32 offset;
        bool isSettled;
        bytes32 payersMerkleRoot;
        uint32[] nodeIds;
    }

    function getPayerReports(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external view returns (PayerReport[] memory payerReports_);
}

/**
 * @title  Subset interface for a Permit ERC20 token.
 * @notice This is the minimal interface needed by contracts within this subdirectory.
 */
interface IPermitErc20Like {
    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external;
}
