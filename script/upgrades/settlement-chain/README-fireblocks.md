# Settlement Chain Upgrades — Fireblocks

## Table of Contents

- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1 `.env` file](#21-env-file)
  - [2.2 `config/<environment>.json`](#22-configenvironmentjson)
- [3. Upgrade Process (Three Steps)](#3-upgrade-process-three-steps)
  - [3.1 Deploy implementation and migrator](#31-deploy-implementation-and-migrator)
  - [3.2 Set migrator in parameter registry (Fireblocks)](#32-set-migrator-in-parameter-registry-fireblocks)
  - [3.3 Perform migration](#33-perform-migration)
- [4. Fireblocks CLI Flags](#4-fireblocks-cli-flags)
- [5. Post-Upgrade](#5-post-upgrade)

## 1. Overview

Use this workflow when the environment defaults to `FIREBLOCKS` or when overriding to use Fireblocks.

## 2. Prerequisites

### 2.1 `.env` file

```bash
DEPLOYER_PRIVATE_KEY=...     # Deployer key (used for steps 1 and 3)
ADMIN=...                    # Fireblocks vault account address
BASE_SEPOLIA_RPC_URL=...     # RPC provider

# Fireblocks configuration (see .env.template)
FIREBLOCKS_API_KEY=...
FIREBLOCKS_API_PRIVATE_KEY_PATH=...
FIREBLOCKS_VAULT_ACCOUNT_IDS=...
# FIREBLOCKS_NOTE is auto-generated if omitted
```

### 2.2 `config/<environment>.json`

```json
{
  "factory": "0x...",                    // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...",     // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..."             // The proxy being upgraded (e.g., nodeRegistryProxy)
}
```

## 3. Upgrade Process (Three Steps)

Fireblocks requires a three-step process because only **Step 2** routes through Fireblocks signing.

| Step | Function                           | Signer   | Fireblocks? |
| ---- | ---------------------------------- | -------- | ----------- |
| 1    | `DeployImplementationAndMigrator()`| DEPLOYER | No          |
| 2    | `SetMigratorInParameterRegistry()` | ADMIN    | **Yes**     |
| 3    | `PerformMigration()`               | DEPLOYER | No          |

As a worked example, the below does an upgrade of `NodeRegistry` on `testnet`.

### 3.1 Deploy implementation and migrator

```bash
ENVIRONMENT=testnet forge script NodeRegistryUpgrader \
  --rpc-url base_sepolia --slow --sig "DeployImplementationAndMigrator()" --broadcast
```

Note the output values:
- `MIGRATOR_ADDRESS_FOR_STEP_2`
- `FIREBLOCKS_NOTE_FOR_STEP_2`

### 3.2 Set migrator in parameter registry (Fireblocks)

```bash
export MIGRATOR_ADDRESS=<value from Step 1>
export FIREBLOCKS_NOTE=<value from Step 1>

ENVIRONMENT=testnet npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryUpgrader \
  --sender $ADMIN --slow --unlocked --rpc-url {} \
  --sig "SetMigratorInParameterRegistry(address)" $MIGRATOR_ADDRESS --broadcast
```

Approve the transaction in the Fireblocks dashboard.

### 3.3 Perform migration

```bash
ENVIRONMENT=testnet forge script NodeRegistryUpgrader \
  --rpc-url base_sepolia --slow --sig "PerformMigration()" --broadcast
```

## 4. Fireblocks CLI Flags

When using `npx fireblocks-json-rpc --http --`:

| Flag | Purpose |
| ---- | ------- |
| `--rpc-url {}` | Proxy replaces `{}` with its URL |
| `--sender $ADMIN` | Address to sign via Fireblocks |
| `--unlocked` | Indicates sender is externally managed |

## 5. Post-Upgrade

1. Copy the `newImpl` address from output to `config/<environment>.json`
2. Verify the implementation:

```bash
forge verify-contract --chain-id 84532 <impl-address> src/settlement-chain/NodeRegistry.sol:NodeRegistry
```
