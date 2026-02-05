# Settlement Chain Upgrades - Wallet (Private Key) <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1. `.env` file](#21-env-file)
  - [2.2. `config/<environment>.json`](#22-configenvironmentjson)
- [3. Upgrade Process (All-in-One)](#3-upgrade-process-all-in-one)
  - [3.1. Setup Defaults](#31-setup-defaults)
  - [3.2. Run Upgrade](#32-run-upgrade)
- [4. Post-Upgrade](#4-post-upgrade)

## 1. Overview

Use this workflow to send admin transactions via `ADMIN_PRIVATE_KEY`. See [environment defaults](README.md#2-environment-defaults) for when this applies.

This is the simpler workflow - the `Upgrade()` function performs all steps in a single transaction batch.

## 2. Prerequisites

### 2.1. `.env` file

```bash
ADMIN_PRIVATE_KEY=...        # Admin private key (for setting migrator in parameter registry)
BASE_SEPOLIA_RPC_URL=...     # Settlement chain RPC endpoint
DEPLOYER_PRIVATE_KEY=...     # Deployer private key (for implementations, migrators, migrations)
ETHERSCAN_API_KEY=...        # For contract verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
```

### 2.2. `config/<environment>.json`

Ensure the following fields are defined correctly in the `config/<environment>.json` file for your chosen environment:

```json
{
  "factory": "0x...", // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...", // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..." // The proxy being upgraded (e.g., nodeRegistryProxy)
}
```

## 3. Upgrade Process (All-in-One)

The `Upgrade()` function performs all steps in a single transaction batch:

1. Deploys the new implementation contract
2. Deploys a migrator contract
3. Sets the migrator in the parameter registry
4. Executes the migration
5. Verifies state is preserved

### 3.1. Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet-dev         # or: testnet-staging, testnet, mainnet
export ADMIN_ADDRESS_TYPE=WALLET       # use wallet private key signing
```

### 3.2. Run Upgrade

Example: Upgrade NodeRegistry:

```bash
forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast
```

## 4. Post-Upgrade

After a successful upgrade:

1. Copy the `newImpl` address from the script output to `config/<environment>.json`
2. Verify the implementation contract on the block explorer:

```bash
forge verify-contract --chain-id 84532 <impl-address> src/settlement-chain/NodeRegistry.sol:NodeRegistry
```
