```solidity
function deposit(uint256 amount_) external {
    _deposit(msg.sender, amount_);
}

function deposit(address account_, uint256 amount_) external {
    _deposit(account_, amount_);
}

function _deposit(address account_, uint256 amount_) internal {
    require(account_ != address(0), InvalidAccount());

    emit Deposit(account_, amount_);

    // More code here
}
```
