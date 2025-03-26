```solidity
// This interface should be in it's own file, but this is just an example.
interface IERC20Like {
    function balanceOf(address account_) external view returns (uint256 balance_);
}

// This interface should be in it's own file, but this is just an example.
interface IFooLike {
    function bar() external;
}

contract Baz {
    address public immutable token;
    address public immutable foo;

    constructor(address token_, address foo_) {
        token = token;
        foo = foo_;
    }

    function faz() external {
        if (IERC20Like(token).balanceOf(address(this)) != 0) return;

        IFooLike(foo).bar();
    }
}
```
