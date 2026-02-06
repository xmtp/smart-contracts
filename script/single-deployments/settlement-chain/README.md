# Settlement Chain Single Deployments <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Environment Defaults](#2-environment-defaults)
- [3. Choose Your Workflow](#3-choose-your-workflow)

## 1. Overview

This directory contains scripts for deploying new contracts on the settlement chain. A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract.

**Important: Admin is NOT Required for Contract Deployment**.

A newly deployed contract's initial state is set via constructor and initializer parameters, NOT from the parameter registry. Anyone with gas tokens can deploy a contract. Admin rights are needed to **update the dependencies** to repoint existing contracts at the newly deployed contract.

This repointing of existing contracts can be done in two ways:

1. If an existing contract caches contract addresses in local storage, we must set a parameter registry value and pull that value into the existing contract (using an `update*()` function in the existing contract). Setting a parameter registry value does required Admin rights. This step is covered as part of the deploy scripts.

2. If an existing contract contains immutable references to a contract that we just redeployed, we must either redeploy or upgrade that existing contract. Immutables are baked into the implementation source code. Generally, we would upgrade the existing contract to use a new implementation with the new immutables. Upgrading does require Admin rights. This must be done as a separate step using the guides in `script/upgrades/settlement-chain/README.md`.

Each deployment follows a three-step process:

1. **Predict Addresses** - Calculate deterministic addresses
2. **Deploy Contract** - Deploy implementation and proxy (uses DEPLOYER)
3. **Update Contract Dependencies** - For case 1 above: set parameter registry values (requires ADMIN) then update dependent contracts (uses DEPLOYER). For case 2 above: manually upgrade an existing contract using the guides in `script/upgrades/settlement-chain/README.md`.

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

## 3. Choose Your Workflow

- **[README-wallet.md](README-wallet.md)** - Private key signing (simpler deployment process)
- **[README-fireblocks.md](README-fireblocks.md)** - Fireblocks signing (multi-step deployment process)
