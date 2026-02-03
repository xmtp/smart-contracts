# Settlement Chain Upgrades — Wallet (Private Key)

## Table of Contents

- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1 `.env` file](#21-env-file)
  - [2.2 `config/<environment>.json`](#22-configenvironmentjson)
- [3. Upgrade Process (All-in-One)](#3-upgrade-process-all-in-one)
  - [3.1 Example: Upgrade NodeRegistry](#31-example-upgrade-noderegistry)
- [4. Post-Upgrade](#4-post-upgrade)

## 1. Overview

Use this workflow when the environment defaults to `ADMIN_PRIVATE_KEY` or when overriding to use a private key.

## 2. Prerequisites

### 2.1 `.env` file

```bash
ADMIN_PRIVATE_KEY=...        # Admin key for setting migrator in parameter registry
DEPLOYER_PRIVATE_KEY=...     # Deployer key for implementations, migrators, migrations
BASE_SEPOLIA_RPC_URL=...     # RPC provider
ETHERSCAN_API_KEY=...        # For verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
```

### 2.2 `config/<environment>.json`

```json
{
  "factory": "0x...", // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...", // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..." // The proxy being upgraded (e.g., nodeRegistryProxy)
}
```

## 3. Upgrade Process (All-in-One)

The `Upgrade()` function performs all steps in a single transaction batch.

### 3.1 Example: Upgrade NodeRegistry

**testnet-dev or testnet-staging (default):**

```bash
ENVIRONMENT=testnet-dev forge script NodeRegistryUpgrader \
  --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast
```

**testnet (override to private key):**

```bash
ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=PRIVATE_KEY forge script NodeRegistryUpgrader \
  --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast
```

## 4. Post-Upgrade

1. Copy the `newImpl` address from output to `config/<environment>.json`
2. Verify the implementation:

```bash
forge verify-contract --chain-id 84532 <impl-address> src/settlement-chain/NodeRegistry.sol:NodeRegistry
```
