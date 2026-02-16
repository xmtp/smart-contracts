# Deploy PayerReportManager <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [Overview](#overview)
- [Step 1: Predict Addresses](#step-1-predict-addresses)
- [Step 2: Deploy Contract](#step-2-deploy-contract)
- [Step 3: Update Dependencies](#step-3-update-dependencies)
  - [3a: Set Parameter Registry Values and Pull Them In](#3a-set-parameter-registry-values-and-pull-them-in)
  - [3b: Upgrade Contracts with Immutable References](#3b-upgrade-contracts-with-immutable-references)

## Overview

Deploys a new **PayerReportManager** proxy and implementation pair using `DeployPayerReportManager.s.sol`.

**Before you begin:** Complete all environment and prerequisite setup in [README.md - Environment and Prerequisites](README.md#3-environment-and-prerequisites), then return here.

**Dependencies managed by this deployment:**

| Method | Parameter Registry Key       | Updated Contract    | Update Function                               |
| ------ | ---------------------------- | ------------------- | --------------------------------------------- |
| 3a     | `xmtp.payerRegistry.settler` | PayerRegistry       | `updateSettler()`                             |
| 3b     | —                            | DistributionManager | Upgrade (immutable `payerReportManagerProxy`) |

## Step 1: Predict Addresses

1. Edit `payerReportManagerProxySalt` in `config/<environment>.json` to a new unique value.
2. Run the prediction script:

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --sig "predictAddresses()"
```

3. Copy the predicted `Implementation` and `Proxy` addresses into `config/<environment>.json` as `payerReportManagerImplementation` and `payerReportManagerProxy`.
4. Run the script again to confirm `Predicted proxy matches payerReportManagerProxy in config JSON.`

The implementation address depends only on bytecode, so it may be unchanged. The `Code already exists at predicted implementation address` warning is expected in that case.

## Step 2: Deploy Contract

1. Remove the existing `payerReportManager` key from `environments/<environment>.json` (the script will rewrite it).
2. Run the deploy:

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

This deploys the implementation, deploys the proxy, initializes the proxy, and writes the new `payerReportManager` proxy address to `environments/<environment>.json`.

## Step 3: Update Dependencies

### 3a: Set Parameter Registry Values and Pull Them In

PayerRegistry caches the settler (PayerReportManager) address in local storage. We need to announce the new proxy address via the parameter registry, then tell PayerRegistry to pull it in.

1. Set `xmtp.payerRegistry.settler` to the new PayerReportManager proxy address (requires ADMIN):

**Wallet:**

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "SetParameterRegistryValues()" --broadcast
```

**Fireblocks:**

```bash
export FIREBLOCKS_NOTE="Deploy PayerReportManager - set settler parameter"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)

npx fireblocks-json-rpc --http -- \
  forge script DeployPayerReportManagerScript --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "SetParameterRegistryValues()" --broadcast
```

The `FIREBLOCKS_EXTERNAL_TX_ID` is an idempotency key (UUID) that prevents duplicate Fireblocks transactions if forge retries the RPC call.

Approve the transaction in the Fireblocks console and wait for it to complete.

> **If forge times out:** Don't panic. The Fireblocks transaction will continue processing independently. Check the Fireblocks console to confirm the transaction was approved and completed on-chain. If it was, proceed to the next step. If you need to re-run, generate a new `FIREBLOCKS_EXTERNAL_TX_ID` (via `uuidgen`) to avoid idempotency conflicts with the completed transaction.

2. Pull the value into PayerRegistry (permissionless, uses DEPLOYER):

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "UpdateContractDependencies()" --broadcast
```

This calls `PayerRegistry.updateSettler()`.

3. Verify the update took effect:

```bash
cast call <payerRegistry-proxy> "settler()(address)" --rpc-url base_sepolia
```

The returned address should match the new PayerReportManager proxy.

### 3b: Upgrade Contracts with Immutable References

The following contracts have immutable constructor references to `payerReportManagerProxy` and must be upgraded or redeployed after a PayerReportManager redeployment:

- **DistributionManager** — has immutable `payerReportManagerProxy`

See the [upgrade guides](../../upgrades/settlement-chain/README.md) for instructions.
