```solidity
pragma solidity ^0.8.0;

// This interface should be in it's own file, but this is just an example.
interface IPayerRegistry {
    /**
     * @notice Returns the balance of a payer.
     * @param  payer_   The address of the payer.
     * @return balance_ The signed balance of the payer (negative if debt).
     */
    function getBalance(address payer_) external view returns (int104 balance_);

    /**
     * @notice Returns the pending withdrawal of a payer.
     * @param  payer_                 The address of the payer.
     * @return pendingWithdrawal_     The amount of a pending withdrawal, if any.
     * @return withdrawableTimestamp_ The timestamp when the pending withdrawal can be finalized.
     */
    function getPendingWithdrawal(
        address payer_
    ) external view returns (uint96 pendingWithdrawal_, uint32 withdrawableTimestamp_);
}

contract PayerRegistry {
    /// @inheritdoc IPayerRegistry
    function getBalance(address payer_) external view returns (int104 balance_) {
        return _payers[payer_].balance;
    }

    /// @inheritdoc IPayerRegistry
    function getPendingWithdrawal(
        address payer_
    ) external view returns (uint96 pendingWithdrawal_, uint32 withdrawableTimestamp_) {
        return (_payers[payer_].pendingWithdrawal, _payers[payer_].withdrawableTimestamp);
    }
}
```
