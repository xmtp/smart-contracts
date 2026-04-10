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

**System invariant:** The live system assumes a stable relationship among `NodeRegistry` node IDs, signer identity, operator databases, and durable on-chain state (notably `PayerReportManager`). That alignment is a **system invariant**; violating it invalidates how history and reports are interpreted.

**Every deployment is a unique event:** Any NodeRegistry deployment must be treated as a **one-off**, not a routine or unattended automation. It **requires human intervention**—explicit assessment, operator coordination, and a chosen plan for either preserving the invariant or executing a controlled breaking migration. See [3b](#3b-upgrade-contracts-with-immutable-references) for continuity requirements and dependent contract upgrades.

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

   For Fireblocks environments, wrap with `npx fireblocks-json-rpc --http --` (see [SetParameter Fireblocks docs](../../parameters/settlement-chain/fireblocks.md)).

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

After the **human-led** invariant check in [Overview](#overview), repoint immutables as follows. The steps below do not substitute for that assessment.

The following contracts have immutable constructor references to `nodeRegistryProxy` and must be upgraded or redeployed after a NodeRegistry redeployment:

- **PayerReportManager** — has immutable `nodeRegistryProxy`
- **DistributionManager** — has immutable `nodeRegistryProxy`

**PayerReportManager holds durable state.** In a running environment, upgrading `PayerReportManager` alone is only safe if the new `NodeRegistry` can be made consistent with what that state and off-chain systems still assume. A fresh `NodeRegistry` starts empty; node IDs are assigned in registration order. Treat the following as **all required** for a non-breaking path:

- Nodes are re-registered in the **same order** as on the old registry (so IDs align with historical payer reports and any stored references).
- **Signing public keys** (and node identity the protocol relies on) match the previous registry for each logical node.
- Operators **preserve node databases** and related off-chain state so messaging, sequences, and reporting stay aligned with chain data.

If any of that fails—different registration order, some nodes not re-registered, changed keys, wiped or divergent databases—on-chain history in `PayerReportManager` will not match how the network behaves. That is a **breaking change**: plan coordinated migration, operator and client communication, and do not assume a standard upgrade is enough.

See the [upgrade guides](../../upgrades/settlement-chain/README.md) for instructions.
