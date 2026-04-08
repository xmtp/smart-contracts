# Any-Chain Single Deployments <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Environment and Prerequisites](#2-environment-and-prerequisites)
  - [2.1. Environment](#21-environment)
  - [2.2. `.env` Variables](#22-env-variables)
  - [2.3. `config/<environment>.json`](#23-configenvironmentjson)
- [3. Supported Deployments](#3-supported-deployments)
- [4. Post-Deployment](#4-post-deployment)

## 1. Overview

This folder contains scripts for deploying contracts that exist on **any chain** (both settlement and app chains). A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract.

These contracts are base-layer infrastructure (e.g. the Factory) that other contracts are deployed through or depend on at deploy time, rather than at runtime.

**Important: Admin is NOT Required for Contract Deployment**.

A newly deployed contract's initial state is set via constructor and initializer parameters, NOT from the parameter registry. Anyone with gas tokens can deploy a contract. Where admin rights are needed for post-deployment steps, the exact steps are documented in the per-contract `.md` files.

## 2. Environment and Prerequisites

Complete all subsections below before starting any deployment listed in the [Supported Deployments](#3-supported-deployments) section.

### 2.1. Environment

Set environment before running any commands:

```bash
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
```

### 2.2. `.env` Variables

Only the deployer key is needed. No admin key is required — all contracts in this folder are deployed and verified using only the DEPLOYER.

```bash
DEPLOYER_PRIVATE_KEY=...               # Deployer private key
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint (or mainnet equivalent)
ETHERSCAN_API_KEY=...                  # For contract verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
```

### 2.3. `config/<environment>.json`

Ensure the following fields are defined correctly for your chosen environment:

```json
{
  "factory": "0x...",
  "parameterRegistryProxy": "0x...",
  "deployer": "0x..."
}
```

Additional per-contract fields (like salts) are documented in each contract's deployment guide.

## 3. Supported Deployments

After completing the prerequisites in section 2 above, follow the remaining steps according to the contract being deployed:

| Contract | Deployment Guide                     | Script                |
| -------- | ------------------------------------ | --------------------- |
| Factory  | [DeployFactory.md](DeployFactory.md) | `DeployFactory.s.sol` |

## 4. Post-Deployment

After a successful deployment:

1. Verify the implementation contract on the block explorer:

   ```bash
   # Base Sepolia (testnet-dev, testnet-staging, testnet)
   forge verify-contract --chain-id 84532 <impl-address> src/any-chain/Factory.sol:Factory

   # Base Mainnet
   forge verify-contract --chain-id 8453 <impl-address> src/any-chain/Factory.sol:Factory
   ```

2. Confirm that `environments/<environment>.json` was updated with the new Factory address (written automatically by `deployContract()` in Step 2).

3. Update `config/<environment>.json` with the new `factory`, `factoryImplementation`, and `initializableImplementation` addresses (see the per-contract deployment guide for details).
