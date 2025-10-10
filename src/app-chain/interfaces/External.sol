// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IArbSysLike {
    function sendTxToL1(address destination_, bytes calldata data_) external payable returns (uint256 messageId_);
}

// slither-disable-next-line name-reused
interface ISettlementChainGatewayLike {
    function receiveWithdrawal(address recipient_) external;

    function receiveWithdrawalIntoUnderlying(address recipient_) external;
}
