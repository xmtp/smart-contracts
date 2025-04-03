```solidity
function finalizeWithdrawal(address recipient_) external returns (bool amount_) {
    // Declarations and instantiations.
    PayerRegistryStorage storage $ = _getPayerRegistryStorage();
    Payer storage payer_ = $.payers[msg.sender];
    uint256 pendingWithdrawal_ = payer_.pendingWithdrawal;

    // Checks.
    +require(recipient_ != address(0), InvalidRecipient());
    require(pendingWithdrawal_ > 0, NoPendingWithdrawal());
    require(payer_.balance >= 0, PayerInDebt());
    require(block.timestamp >= payer_.withdrawableTimestamp, WithdrawalNotReady());

    // Effects, deletions.
    delete payer_.pendingWithdrawal;
    delete payer_.withdrawableTimestamp;

    // Effects, modifications.
    $.totalDeposits -= _toInt104(pendingWithdrawal_);

    // Effects, events.
    emit WithdrawalFinalized(msg.sender);

    // Effects, function calls (which may or may not yet be interactions).
    _foo();

    // Interactions.
    require(ERC20Helper.transfer(token, recipient_, pendingWithdrawal_), ERC20TransferFailed());

    // Returns.
    return pendingWithdrawal_;
}
```
