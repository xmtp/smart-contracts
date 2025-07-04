// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IArbSysLike {
    function sendTxToL1(address destination_, bytes calldata data_) external payable returns (uint256 messageId_);
}

interface ISettlementChainGatewayLike {
    function withdraw(address recipient_) external;

    function withdrawIntoUnderlying(address recipient_) external;
}
