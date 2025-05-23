// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IArbSysLike {
    function withdrawEth(address recipient_) external payable;
}
