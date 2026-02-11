# Settlement Chain Single Deployments <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Overview of Three-Step Deployment Process](#2-overview-of-three-step-deployment-process)
- [3. Environment and Prerequisites](#3-environment-and-prerequisites)
  - [3.1. Environment Defaults](#31-environment-defaults)
  - [3.2. `.env` Variables](#32-env-variables)
  - [3.3. `config/<environment>.json`](#33-configenvironmentjson)
- [4. Supported Deployments](#4-supported-deployments)
- [5. Post-Deployment](#5-post-deployment)

## 1. Overview

This folder contains scripts for deploying new contracts on the settlement chain. A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract.

**Important: Admin is NOT Required for Contract Deployment**.

A newly deployed contract's initial state is set via constructor and initializer parameters, NOT from the parameter registry. Anyone with gas tokens can deploy a contract. Admin rights are needed to **update the dependencies** to repoint existing contracts at the newly deployed contract. Where admin rights are needed, the exact steps vary depending on if you are using a private key versus Fireblocks to manage the admin address. All steps are documented in the `.md` files in this folder.

## 2. Overview of Three-Step Deployment Process

This section is an overview of the deployment process, the exact steps to follow are detailed in the per-contract guides linked in [Supported Deployments](#4-supported-deployments). Each deployment follows a three-step process. Steps 1 and 2 are the same for all contracts, step 3 is specific to each contract:

| Step | Description         | Signer                |
| ---- | ------------------- | --------------------- |
| 1    | Predict Addresses   | Not required          |
| 2    | Deploy Contract     | DEPLOYER              |
| 3    | Update Dependencies | ADMIN and/or DEPLOYER |

**Step 1: Predict Addresses.** Calculate deterministic addresses for the implementation and proxy using `predictAddresses()`. Copy the predicted addresses to `config/<environment>.json`.

**Step 2: Deploy Contract.** Deploy the implementation and proxy pair using `deployContract()`. This updates `environments/<environment>.json` with the new proxy address. This does not need an ADMIN address.

**Step 3: Update Dependencies.** Repoint existing contracts at the newly deployed contract. This has two methods, applied as needed per contract:

- **3a) Set parameter registry values and pull them in.** If an existing contract caches contract addresses in local storage, we set a parameter registry value (requires ADMIN via `SetParameterRegistryValues()`) and then pull that value into the existing contract via a permissionless `update*()` function (uses DEPLOYER via `UpdateContractDependencies()`).

- **3b) Upgrade/redeploy contracts with immutable references.** If an existing contract contains immutable references to the contract we just redeployed, we must upgrade or redeploy that contract. Immutables are baked into the implementation source code. Generally, we upgrade the existing contract using the [upgrade guides](../../upgrades/settlement-chain/README.md).

## 3. Environment and Prerequisites

Complete all subsections below before starting any deployment listed in the [Supported Deployments](#4-supported-deployments) section.

### 3.1. Environment Defaults

Admin address type is determined by environment with optional `ADMIN_ADDRESS_TYPE` override:

| Environment       | Default Admin Type | Can Override? | Notes                      |
| ----------------- | ------------------ | ------------- | -------------------------- |
| `testnet-dev`     | WALLET             | Yes           | Use WALLET for development |
| `testnet-staging` | WALLET             | Yes           | Use WALLET for staging     |
| `testnet`         | FIREBLOCKS         | Yes           | Use FIREBLOCKS for testnet |
| `mainnet`         | FIREBLOCKS         | No            | FIREBLOCKS always enforced |

Set environment and admin type before running any commands:

```bash
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
export ADMIN_ADDRESS_TYPE=FIREBLOCKS   # or WALLET (optional override)
```

### 3.2. `.env` Variables

All environments need:

```bash
DEPLOYER_PRIVATE_KEY=...               # Deployer private key
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint
ETHERSCAN_API_KEY=...                  # For contract verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
```

Wallet signing additionally needs:

```bash
ADMIN=...                              # Admin account address. This needs replaced with Fireblocks value if Fireblocks is used.
ADMIN_PRIVATE_KEY=...                  # Admin private key. This is ignored if Fireblocks is used.
```

Fireblocks signing additionally needs:

```bash
ADMIN=...                              # Fireblocks vault account address (this replaces the Wallet ADMIN address above)
FIREBLOCKS_API_KEY=...                 # From Fireblocks console (Settings -> Users, find API user)
FIREBLOCKS_API_PRIVATE_KEY_PATH=...    # Path to API private key file (download from 1Password)
FIREBLOCKS_VAULT_ACCOUNT_IDS=...       # Vault account ID that owns the ADMIN address
```

### 3.3. `config/<environment>.json`

Ensure the following fields are defined correctly for your chosen environment:

```json
{
  "factory": "0x...",
  "parameterRegistryProxy": "0x...",
  "deployer": "0x..."
}
```

## 4. Supported Deployments

After completing the prerequisites in section 3 above, follow the remaining steps according to the contract being deployed:

| Contract            | Deployment Guide                                             | Script                            |
| ------------------- | ------------------------------------------------------------ | --------------------------------- |
| NodeRegistry        | [DeployNodeRegistry.md](DeployNodeRegistry.md)               | `DeployNodeRegistry.s.sol`        |
| PayerReportManager  | [DeployPayerReportManager.md](DeployPayerReportManager.md)   | `DeployPayerReportManager.s.sol`  |
| DistributionManager | [DeployDistributionManager.md](DeployDistributionManager.md) | `DeployDistributionManager.s.sol` |

## 5. Post-Deployment

After a successful deployment:

1. Verify the implementation contract on the block explorer. Use the chain ID for your target network:

```bash
# Base Sepolia (testnet-dev, testnet-staging, testnet)
forge verify-contract --chain-id 84532 <impl-address> src/settlement-chain/<Contract>.sol:<Contract>

# Base Mainnet
forge verify-contract --chain-id 8453 <impl-address> src/settlement-chain/<Contract>.sol:<Contract>
```

2. Confirm that `environments/<environment>.json` was updated with the new proxy address (written automatically by `deployContract()` in Step 2).
