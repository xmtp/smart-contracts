```solidity
function toggleUsers(address[] calldata users_) external {
    for (uint256 index_; index_ < users_.length; ++i) {
        address user_ = users_[index_];
        isUser(user_) ? _removeUser(user_) : _addUser(user_);
    }
}

function _removeUser(address user_) internal {
    uint256 balance_ = _users[user_].balance;
    delete _users[user_];
    emit UserRemoved(user_);
}

function _addUser(address user_) internal {
    _users[user_].active = true;
    emit UserAdded(user_);

    address endorser_ = _getEndorser(user_);

    if (endorser_ != address(0)) {
        _users[user_].endorser = endorser_;
        _giveReward(endorser_);
        return;
    }

    uint256 fee_ = _takeRegistrationFee(user_);
    _users[user_].balance = fee_;
}
```
