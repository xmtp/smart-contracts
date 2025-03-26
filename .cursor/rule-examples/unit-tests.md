```solidity
function test_finalizeWithdrawal() external {
    // Minimal amount of state setup needed for the test, via a harness.
    _registry.__setPendingWithdrawal(_alice, 10e6);
    _registry.__setPendingWithdrawableTimestamp(_alice, uint32(vm.getBlockTimestamp()));

    // Expected contract interaction.
    vm.expectCall(_token, abi.encodeWithSelector(MockErc20.transfer.selector, _alice, 10e6));

    // Expected event emission.
    vm.expectEmit(address(_registry));
    emit IPayerRegistry.WithdrawalFinalized(_alice);

    vm.prank(_alice);
    _registry.finalizeWithdrawal(_alice); // Only function being tested.

    // Expected state changes.

    // This public getter is a simple individual state accessor.
    assertEq(_registry.getBalance(_alice), 0);

    // Since there are no simple individual state accessor for these, use harness functions to access them individually.
    assertEq(_registry.__getPendingWithdrawal(_alice), 0);
    assertEq(_registry.__getPendingWithdrawableTimestamp(_alice), 0);
}
```
