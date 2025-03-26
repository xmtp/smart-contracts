```solidity
function getFoo(uint256[] calldata values_) external view returns (uint256 foo_) {
    require(values_.length >= MIN_VALUES_LENGTH, InvalidValuesLength());

    for (uint256 index_; index_ < values_.length; ++index_) {
        uint256 value_ = values_[index_];

        if (value_ < MIN_VALUE || value_ > MAX_VALUE) {
            return;
        }

        foo_ += value_;
    }
}
```
