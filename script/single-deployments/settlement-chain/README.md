# Settlement Chain Single Deployments <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Environment Defaults](#2-environment-defaults)
- [3. Workflow Selection](#3-workflow-selection)
  - [3.1. Wallet Workflow (Private Key)](#31-wallet-workflow-private-key)
  - [3.2. Fireblocks Workflow](#32-fireblocks-workflow)
- [4. Available Deployment Scripts](#4-available-deployment-scripts)
  - [4.1. DeployNodeRegistry.s.sol](#41-deploynoderegistryssol)
  - [4.2. DeployPayerReportManager.s.sol](#42-deploypayerreportmanagerssol)
  - [4.3. DeployDistributionManager.s.sol](#43-deploydistributionmanagerssol)

## 1. Overview

This directory contains scripts for deploying new contracts on the settlement chain. A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract.

**Important: Admin is NOT Required for Contract Deployment**

A newly deployed contract's initial state is set via constructor and initializer parameters, NOT from the parameter registry. Anyone with gas tokens can deploy a contract. Admin rights are needed to **update dependencies**, to repoint existing contracts at the newly deployed contract.

This repointing of existing contracts can be done in two ways:

1. If an existing contract caches contract addresses in local storage, we must set a parameter registry value and pull that value into the existing contract (using an `update*()` function in the existing contract). This is covered as part of the deploy scripts.

2. If an existing contract contains immutable references to a contract that we just redeployed, we must upgrade the existing contract. Immutables are baked into the implementation source code. This must be done as a separate step using the guides in `script/upgrades/settlement-chain/README.md`.

Each deployment follows a four-step process:

1. **Predict Addresses** - Calculate deterministic addresses
2. **Deploy Contract** - Deploy implementation and proxy (uses DEPLOYER)
3. **Set Parameter Registry Values** - Set parameters (requires ADMIN)
4. **Update Contract Dependencies** - Update dependent contracts (uses DEPLOYER) for case 1 above, or manually upgrade an existing contract for case 2 above.

## 2. Environment Defaults

Admin address type is determined by environment with optional `ADMIN_ADDRESS_TYPE` override:

| Environment       | Default Admin Type | Can Override? | Notes                      |
| ----------------- | ------------------ | ------------- | -------------------------- |
| `testnet-dev`     | WALLET             | Yes           | Use WALLET for development |
| `testnet-staging` | WALLET             | Yes           | Use WALLET for staging     |
| `testnet`         | FIREBLOCKS         | Yes           | Use FIREBLOCKS for testnet |
| `mainnet`         | FIREBLOCKS         | No            | FIREBLOCKS always enforced |

Override by setting:

```bash
export ADMIN_ADDRESS_TYPE=FIREBLOCKS  # or WALLET
```

## 3. Workflow Selection

Choose the appropriate workflow based on your environment:

### 3.1. Wallet Workflow (Private Key)

- **Use for:** `testnet-dev`, `testnet-staging`
- **Requirements:** `ADMIN_PRIVATE_KEY`, `DEPLOYER_PRIVATE_KEY`
- **Documentation:** [README-wallet.md](README-wallet.md)

### 3.2. Fireblocks Workflow

- **Use for:** `testnet`, `mainnet`
- **Requirements:** `ADMIN` (Fireblocks vault address), `DEPLOYER_PRIVATE_KEY`, Fireblocks API credentials
- **Documentation:** [README-fireblocks.md](README-fireblocks.md)

## 4. Available Deployment Scripts

### 4.1. DeployNodeRegistry.s.sol

Deploys a new NodeRegistry contract (proxy and implementation).

**Dependencies:**

- Reads from parameter registry: `xmtp.nodeRegistry.admin`, `xmtp.nodeRegistry.maxCanonicalNodes`
- Updates: NodeRegistry contract via `updateAdmin()` and `updateMaxCanonicalNodes()`

**Note:** NodeRegistry has no parameters to set in Step 3. Parameters must be set manually before Step 4.

### 4.2. DeployPayerReportManager.s.sol

Deploys a new PayerReportManager contract (proxy and implementation).

**Dependencies:**

- Sets in parameter registry: `xmtp.payerRegistry.settler`
- Updates: PayerRegistry contract via `updateSettler()`

**Post-deployment:** A new DistributionManager must also be upgraded or deployed since it has an immutable reference to the PayerReportManager address.

### 4.3. DeployDistributionManager.s.sol

Deploys a new DistributionManager contract (proxy and implementation).

**Dependencies:**

- Sets in parameter registry: `xmtp.payerRegistry.feeDistributor`
- Updates: PayerRegistry contract via `updateFeeDistributor()`

**Note:** DistributionManager has an immutable constructor parameter pointing to PayerReportManager, so it must be upgraded or redeployed when PayerReportManager changes.
