# Deploy NodeRegistry <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [Overview](#overview)
- [Step 1: Predict Addresses](#step-1-predict-addresses)
- [Step 2: Deploy Contract](#step-2-deploy-contract)
- [Step 3: Update Dependencies](#step-3-update-dependencies)
  - [3a: Set Parameter Registry Values and Pull Them In](#3a-set-parameter-registry-values-and-pull-them-in)
  - [3b: Upgrade Contracts with Immutable References](#3b-upgrade-contracts-with-immutable-references)

## Overview

Deploys a new **NodeRegistry** proxy and implementation pair using `DeployNodeRegistry.s.sol`.

**Before you begin:** Complete all environment and prerequisite setup in [README.md - Environment and Prerequisites](README.md#3-environment-and-prerequisites), then return here.

**Dependencies managed by this deployment:**

| Method | Parameter Registry Key                | Updated Contract    | Update Function                         |
| ------ | ------------------------------------- | ------------------- | --------------------------------------- |
| 3a     | `xmtp.nodeRegistry.admin`             | NodeRegistry        | `updateAdmin()`                         |
| 3a     | `xmtp.nodeRegistry.maxCanonicalNodes` | NodeRegistry        | `updateMaxCanonicalNodes()`             |
| 3b     | —                                     | PayerReportManager  | Upgrade (immutable `nodeRegistryProxy`) |
| 3b     | —                                     | DistributionManager | Upgrade (immutable `nodeRegistryProxy`) |

## Step 1: Predict Addresses

1. Edit `nodeRegistryProxySalt` in `config/<environment>.json` to a new unique value.
2. Run the prediction script:

```bash
forge script DeployNodeRegistryScript --rpc-url base_sepolia --sig "predictAddresses()"
```

3. Copy the predicted `Implementation` and `Proxy` addresses into `config/<environment>.json` as `nodeRegistryImplementation` and `nodeRegistryProxy`.
4. Run the script again to confirm `Predicted proxy matches nodeRegistryProxy in config JSON.`

The implementation address depends only on bytecode, so it may be unchanged. The `Code already exists at predicted implementation address` warning is expected in that case.

## Step 2: Deploy Contract

1. Remove the existing `nodeRegistry` key from `environments/<environment>.json` (the script will rewrite it).
2. Run the deploy:

```bash
forge script DeployNodeRegistryScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

This deploys the implementation, deploys the proxy, initializes the proxy, and writes the new `nodeRegistry` proxy address to `environments/<environment>.json`.

## Step 3: Update Dependencies

### 3a: Set Parameter Registry Values and Pull Them In

NodeRegistry's `SetParameterRegistryValues()` is a no-op, there is no "new NodeRegistry address" to announce to the parameter registry, because no other contract reads it (any references to the NodeRegistry from other contracts are [immutables](#3b-upgrade-contracts-with-immutable-references)). However, the new NodeRegistry still needs to pull in its `admin` and `maxCanonicalNodes` values. These must be set in the parameter registry before proceeding.

1. Read the current values from the **old** NodeRegistry (cast calls against the old proxy address):

```bash
cast call <old-nodeRegistry-proxy> "admin()(address)" --rpc-url base_sepolia
cast call <old-nodeRegistry-proxy> "maxCanonicalNodes()(uint8)" --rpc-url base_sepolia
```

2. Set them in the parameter registry using the [SetParameter script](../../parameters/settlement-chain/README.md):

```bash
# Set admin address
forge script SetParameter --rpc-url base_sepolia --slow --sig "setAddress(string,address)" "xmtp.nodeRegistry.admin" <admin-address> --broadcast

# Set maxCanonicalNodes
forge script SetParameter --rpc-url base_sepolia --slow --sig "setUint(string,uint256)" "xmtp.nodeRegistry.maxCanonicalNodes" <value> --broadcast
```

For Fireblocks environments, wrap with `npx fireblocks-json-rpc --http --` (see [SetParameter Fireblocks docs](../../parameters/settlement-chain/README-fireblocks.md)).

3. Pull the values into the new NodeRegistry contract:

```bash
forge script DeployNodeRegistryScript --rpc-url base_sepolia --slow --sig "UpdateContractDependencies()" --broadcast
```

This calls `NodeRegistry.updateAdmin()` and `NodeRegistry.updateMaxCanonicalNodes()` (permissionless, uses DEPLOYER).

4. Verify the updates took effect:

```bash
cast call <nodeRegistry-proxy> "admin()(address)" --rpc-url base_sepolia
cast call <nodeRegistry-proxy> "maxCanonicalNodes()(uint8)" --rpc-url base_sepolia
```

The returned values should match what was set in step 2.

### 3b: Upgrade Contracts with Immutable References

The following contracts have immutable constructor references to `nodeRegistryProxy` and must be upgraded or redeployed after a NodeRegistry redeployment:

- **PayerReportManager** — has immutable `nodeRegistryProxy`
- **DistributionManager** — has immutable `nodeRegistryProxy`

See the [upgrade guides](../../upgrades/settlement-chain/README.md) for instructions.
