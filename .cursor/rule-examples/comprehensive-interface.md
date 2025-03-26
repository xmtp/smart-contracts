```solidity
pragma solidity ^0.8.0;

// This interface should be in it's own file, but this is just an example.
interface IFoo is IERC20, IPausable, IOwnable {}

contract Foo is IFoo, Pausable, Ownable, UUPSUpgradeable {}
```
