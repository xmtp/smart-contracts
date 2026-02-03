# Settlement Chain Upgrades — Fireblocks

## Table of Contents

- [Settlement Chain Upgrades — Fireblocks](#settlement-chain-upgrades--fireblocks)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Prerequisites](#2-prerequisites)
    - [2.1 `.env` file](#21-env-file)
    - [2.2 `config/<environment>.json`](#22-configenvironmentjson)
  - [3. Upgrade Process (Three Steps)](#3-upgrade-process-three-steps)
    - [3.0 Setup Defaults](#30-setup-defaults)
    - [3.1 Step 1: Deploy implementation and migrator](#31-step-1-deploy-implementation-and-migrator)
    - [3.2 Step 2: Set migrator in parameter registry (Fireblocks)](#32-step-2-set-migrator-in-parameter-registry-fireblocks)
    - [3.3 Step 3: Perform migration](#33-step-3-perform-migration)
  - [4. Fireblocks Local RPC](#4-fireblocks-local-rpc)
  - [5. Post-Upgrade](#5-post-upgrade)

## 1. Overview

Use this workflow to send admin transactions via the Fireblocks-managed admin address. See [environment defaults](README.md#2-environment-defaults) for when this applies.

Fireblocks requires a **three-step process** because only Step 2 (setting the migrator) routes through Fireblocks signing. Steps 1 and 3 use the deployer key directly.

## 2. Prerequisites

### 2.1 `.env` file

```bash
ADMIN=...                              # Fireblocks vault account address (the admin)
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint
DEPLOYER_PRIVATE_KEY=...               # Deployer private key (for Steps 1 and 3)
ETHERSCAN_API_KEY=...                  # For contract verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
FIREBLOCKS_API_KEY=...                 # From Fireblocks console → Settings → API Users
FIREBLOCKS_API_PRIVATE_KEY_PATH=...    # Path to API private key file (download from 1Password)
FIREBLOCKS_VAULT_ACCOUNT_IDS=...       # Vault account ID that owns the ADMIN address
```

### 2.2 `config/<environment>.json`

Ensure the following fields are defined correctly for your chosen environment:

```json
{
  "factory": "0x...", // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...", // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..." // The proxy being upgraded (e.g., nodeRegistryProxy)
}
```

## 3. Upgrade Process (Three Steps)

| Step | Function                            | Signer   | Fireblocks? |
| ---- | ----------------------------------- | -------- | ----------- |
| 1    | `DeployImplementationAndMigrator()` | DEPLOYER | No          |
| 2    | `SetMigratorInParameterRegistry()`  | ADMIN    | **Yes**     |
| 3    | `PerformMigration()`                | DEPLOYER | No          |

The following example upgrades `NodeRegistry` on `testnet`.

### 3.0 Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
export ADMIN_ADDRESS_TYPE=FIREBLOCKS   # use Fireblocks signing
```

### 3.1 Step 1: Deploy implementation and migrator

This step deploys the new implementation and creates a migrator contract:

```bash
forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow \
  --sig "DeployImplementationAndMigrator()" --broadcast
```

**Important:** Note the output values — you will need them for Step 2:

- `MIGRATOR_ADDRESS_FOR_STEP_2` — the migrator contract address
- `FIREBLOCKS_NOTE_FOR_STEP_2` — a descriptive note for the Fireblocks transaction

### 3.2 Step 2: Set migrator in parameter registry (Fireblocks)

Export the values from Step 1, then run the Fireblocks command:

```bash
export MIGRATOR_ADDRESS=<value from Step 1>
export FIREBLOCKS_NOTE=<value from Step 1>

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "SetMigratorInParameterRegistry(address)" $MIGRATOR_ADDRESS --broadcast
```

Approve the transaction in the Fireblocks console.

### 3.3 Step 3: Perform migration

After the Fireblocks transaction is confirmed, execute the migration:

```bash
forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow \
  --sig "PerformMigration()" --broadcast
```

The script will verify that contract state is preserved after the upgrade.

## 4. Fireblocks Local RPC

The Fireblocks JSON-RPC proxy runs locally and redirects signing requests to Fireblocks.

When you see `npx fireblocks-json-rpc --http --`, it:

1. Starts a local RPC server
2. Executes the forge command
3. Routes signing requests to Fireblocks for approval
4. Shuts down after the command completes

| Flag              | Purpose                                                          |
| ----------------- | ---------------------------------------------------------------- |
| `--rpc-url {}`    | The local RPC injects its URL in place of `{}`                   |
| `--sender $ADMIN` | Specifies the Fireblocks-managed address for the transaction     |
| `--unlocked`      | Indicates the sender address is managed externally               |
| `--timeout 3600`  | Wait up to 1 hour for Fireblocks approval (prevents early abort) |
| `--retries 1`     | Minimal retries to prevent duplicate transactions in Fireblocks  |

## 5. Post-Upgrade

After a successful upgrade:

1. Copy the `newImpl` address from the script output to `config/<environment>.json`
2. Verify the implementation contract on the block explorer:

```bash
forge verify-contract --chain-id 84532 <impl-address> src/settlement-chain/NodeRegistry.sol:NodeRegistry
```
