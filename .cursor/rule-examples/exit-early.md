```solidity
function foo() external {
    if (block.timestamp < checkpoint) return;

    if (balance() < threshold) {
        _pushCheckpoint();
        return;
    }

    // More code here
}
```
