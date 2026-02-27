# Custom Migration Guide

How to perform an upgrade that includes data migration, backfill, or storage reorganization — not just an implementation swap.

## Background

The standard upgrade path uses `GenericEIP1967Migrator`, which writes a new implementation address into the EIP-1967 slot and nothing else. When an upgrade also needs to transform on-chain state (populate a new data structure, reorganize storage, backfill derived data, etc.), you need a **custom migrator**.

Custom migrators are delegatecalled by the proxy during `migrate()`, so they execute in the proxy's storage context and can read/write any storage slot.

## Step-by-step

### 1. Write the custom migrator contract

Create a new contract in `src/any-chain/` (or the appropriate chain-specific directory). It must:

- Accept the new implementation address in its constructor and store it as an `immutable`.
- Implement a `fallback()` that:
  1. Writes the new implementation into the EIP-1967 slot.
  2. Emits `IERC1967.Upgraded(newImpl)`.
  3. Performs whatever data migration is needed.

Use `GenericEIP1967Migrator` as a starting point and `NodeRegistryBackfillMigrator` as a reference for a migrator that also does data work.

**Key constraints:**

- The migrator runs via `delegatecall`, so storage reads/writes operate on the **proxy's** layout. If you need to access a contract's namespaced storage, replicate the storage struct and location constant exactly.
- The migration must be **idempotent** — calling it twice should produce the same result, since `migrate()` can be retried.
- Keep gas costs in mind. If iterating over unbounded data, consider whether the migration could exceed the block gas limit and whether batching is needed.

### 2. Write unit tests

Create tests in `test/unit/` using a mock proxy that exercises the migrator in isolation. Test:

- Constructor validation (e.g. zero-address rejection).
- The implementation slot is written correctly.
- The data migration produces the expected state.
- Idempotency (calling the migrator twice yields the same result).
- Edge cases (empty state, already-migrated data, partial states).

### 3. Override `_deployMigrator` in the upgrader script

In `BaseSettlementChainUpgrader`, migrator creation is a virtual method:

```solidity
function _deployMigrator(address newImpl_) internal virtual returns (address migrator_) {
    return address(new GenericEIP1967Migrator(newImpl_));
}
```

Override it in your contract's upgrader (e.g. `NodeRegistryUpgrader`):

```solidity
import { MyCustomMigrator } from "../../../src/any-chain/MyCustomMigrator.sol";

// TODO: Remove this override after the one-off migration is complete.
function _deployMigrator(address newImpl_) internal override returns (address migrator_) {
    return address(new MyCustomMigrator(newImpl_));
}
```

This plugs into both the all-in-one `Upgrade()` flow and the three-step Fireblocks flow with no other changes needed.

### 4. Adjust the state comparison

The upgrader's `_isContractStateEqual()` compares state snapshots before and after migration. If your migration intentionally changes state, update this method to allow the expected changes while still guarding against unexpected ones.

For example, if a migration populates a new array, you might relax the check from strict equality to "must not decrease":

```solidity
isEqual_ = isEqual_ && afterState.count >= before.count;
```

Mark these relaxations with a TODO so they can be tightened back after the migration ships.

### 5. Write a fork test

Create a fork test in `test/upgrades/` following the existing `*.fork.t.sol` pattern. This exercises the full migration against real on-chain state:

```solidity
function setUp() external {
    string memory rpc = vm.rpcUrl("base_sepolia");
    vm.createSelectFork(rpc);
    // ...
}
```

### 6. (Optional) Interactive verification with Anvil

For hands-on exploration, fork the target chain locally with Anvil and step through the migration interactively using `forge create` and `cast`. See `doc/anvil-fork-testing-workflow.md` for a detailed walkthrough.

### 7. Deploy

Run the upgrader script exactly as you would for a normal upgrade. The custom migrator is deployed automatically via your `_deployMigrator` override:

```bash
# All-in-one (non-Fireblocks)
ENVIRONMENT=testnet forge script YourContractUpgrader --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast

# Or three-step (Fireblocks) — same as normal, the migrator swap is transparent
```

### 8. Clean up after the migration

Once the migration has been applied to all target environments:

1. **Remove the `_deployMigrator` override** from the upgrader so future upgrades revert to `GenericEIP1967Migrator`.
2. **Revert any relaxed state checks** in `_isContractStateEqual` back to strict equality.
3. The custom migrator contract in `src/` can remain — it's deployed on-chain and may be useful as a reference — but it won't be used again.
