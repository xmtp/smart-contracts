// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// TODO: `calculateRetryableSubmissionFee` might actually be part of the counterpart inbox. Investigate.

/**
 * @title IERC20Like
 * @notice Minimal interface for ERC20 token balance checks
 */
interface IERC20Like {
    function balanceOf(address account) external view returns (uint256 balance);
}

interface IERC20InboxLike {
    function sendContractTransaction(
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        address to_,
        uint256 value_,
        bytes calldata data_
    ) external returns (uint256 messageNumber_);

    /**
     * @notice Put a message in the L2 inbox that can be reexecuted for some fixed amount of time if it reverts
     * @dev all tokenTotalFeeAmount will be deposited to callValueRefundAddress on L2
     * @dev Gas limit and maxFeePerGas should not be set to 1 as that is used to trigger the RetryableData error
     * @dev In case of native token having non-18 decimals: tokenTotalFeeAmount is denominated in native token's decimals. All other value params - l2CallValue, maxSubmissionCost and maxFeePerGas are denominated in child chain's native 18 decimals.
     * @param to_ destination L2 contract address
     * @param l2CallValue_ call value for retryable L2 message
     * @param maxSubmissionCost_ Max gas deducted from user's L2 balance to cover base submission fee
     * @param excessFeeRefundAddress_ the address which receives the difference between execution fee paid and the actual execution cost. In case this address is a contract, funds will be received in its alias on L2.
     * @param callValueRefundAddress_ l2Callvalue gets credited here on L2 if retryable txn times out or gets cancelled. In case this address is a contract, funds will be received in its alias on L2.
     * @param gasLimit_ Max gas deducted from user's L2 balance to cover L2 execution. Should not be set to 1 (magic value used to trigger the RetryableData error)
     * @param maxFeePerGas_ price bid for L2 execution. Should not be set to 1 (magic value used to trigger the RetryableData error)
     * @param tokenTotalFeeAmount_ amount of fees to be deposited in native token to cover for retryable ticket cost
     * @param data_ ABI encoded data of L2 message
     * @return messageNumber_ message number of the retryable transaction
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

    /**
     * @notice Deposit native token from L1 to L2 to address of the sender if sender is an EOA, and to its aliased address if the sender is a contract
     * @dev This does not trigger the fallback function when receiving in the L2 side.
     *      Look into retryable tickets if you are interested in this functionality.
     * @dev This function should not be called inside contract constructors
     */
    function depositERC20(uint256 amount_) external returns (uint256 messageNumber_);

    /**
     * @notice Get the L1 fee for submitting a retryable
     * @dev This fee can be paid by funds already in the L2 aliased address or by the current message value
     * @dev This formula may change in the future, to future proof your code query this method instead of inlining!!
     * @param dataLength_ The length of the retryable's calldata, in bytes
     * @param baseFee_ The block basefee when the retryable is included in the chain, if 0 current block.basefee will be used
     */
    function calculateRetryableSubmissionFee(
        uint256 dataLength_,
        uint256 baseFee_
    ) external view returns (uint256 submissionFee_);
}

interface IAppChainGatewayLike {
    function receiveParameters(uint256 nonce_, bytes[][] calldata keyChains_, bytes32[] calldata values_) external;
}

interface IParameterRegistryLike {
    function get(bytes[][] calldata keyChains_) external view returns (bytes32[] memory values_);

    function get(bytes[] calldata keyChain_) external view returns (bytes32 value_);
}
