# App Chain Upgrades - Fireblocks

## Table of Contents

- [App Chain Upgrades - Fireblocks](#app-chain-upgrades---fireblocks)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Step Summary \& Token Requirements](#2-step-summary--token-requirements)
  - [3. Prerequisites](#3-prerequisites)
    - [3.1 `.env` file](#31-env-file)
    - [3.2 `config/<environment>.json`](#32-configenvironmentjson)
  - [4. Upgrade Process (Four Steps)](#4-upgrade-process-four-steps)
    - [4.0 Setup Defaults](#40-setup-defaults)
    - [4.1 Step 1: Prepare (app chain)](#41-step-1-prepare-app-chain)
    - [4.2 Step 2: SetMigrator (settlement chain)](#42-step-2-setmigrator-settlement-chain)
    - [4.3 Step 3: BridgeParameter (settlement chain)](#43-step-3-bridgeparameter-settlement-chain)
    - [4.4 Step 4: Upgrade (app chain)](#44-step-4-upgrade-app-chain)
  - [5. Fireblocks Local RPC](#5-fireblocks-local-rpc)
  - [6. Post-Upgrade](#6-post-upgrade)

## 1. Overview

Use this workflow to send admin transactions via the Fireblocks-managed admin address. See [environment defaults](README.md#2-environment-defaults) for when this applies.

App chain upgrades are **four steps** because they span two chains. The migrator address must be set on the settlement chain and bridged to the app chain. In Fireblocks mode, steps 2-3 must be run separately (step 2 via Fireblocks, step 3 without).

## 2. Step Summary & Token Requirements

| Step               | Chain      | Address  | baseETH | xUSD (settlement) | xUSD (app) | Note                                                                        |
| ------------------ | ---------- | -------- | ------- | ----------------- | ---------- | --------------------------------------------------------------------------- |
| 1. Prepare         | App        | DEPLOYER | -       | -                 | Yes        | Deploy new implementation and migrator contracts                            |
| 2. SetMigrator     | Settlement | ADMIN    | Yes     | -                 | -          | Set migrator address in settlement chain parameter registry (admin-only tx) |
| 3. BridgeParameter | Settlement | DEPLOYER | Yes     | Yes               | -          | Bridge the migrator parameter to app chain                                  |
| 4. Upgrade         | App        | DEPLOYER | -       | -                 | Yes        | Execute migration on app chain using bridged migrator                       |

## 3. Prerequisites

### 3.1 `.env` file

```bash
ADMIN=...                              # Fireblocks vault account address
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint
DEPLOYER_PRIVATE_KEY=...               # Deployer private key (for all steps)
ETHERSCAN_API_KEY=...                  # For contract verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
FIREBLOCKS_API_KEY=...                 # From Fireblocks console → Settings → API Users
FIREBLOCKS_API_PRIVATE_KEY_PATH=...    # Path to API private key file (download from 1Password)
FIREBLOCKS_VAULT_ACCOUNT_IDS=...       # Vault account ID that owns the ADMIN address
XMTP_ROPSTEN_RPC_URL=...               # App chain RPC endpoint
```

### 3.2 `config/<environment>.json`

Ensure the following fields are defined correctly for your chosen environment:

```json
{
  "factory": "0x...", // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...", // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..." // The proxy being upgraded (e.g., identityUpdateBroadcasterProxy)
}
```

## 4. Upgrade Process (Four Steps)

| Step | Function                           | Chain      | Signer   | Fireblocks? |
| ---- | ---------------------------------- | ---------- | -------- | ----------- |
| 1    | `Prepare()`                        | App        | DEPLOYER | No          |
| 2    | `SetMigratorInParameterRegistry()` | Settlement | ADMIN    | **Yes**     |
| 3    | `BridgeParameter()`                | Settlement | DEPLOYER | No          |
| 4    | `Upgrade()`                        | App        | DEPLOYER | No          |

The following example upgrades `IdentityUpdateBroadcaster` on `testnet`.

### 4.0 Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
export ADMIN_ADDRESS_TYPE=FIREBLOCKS   # use Fireblocks signing
```

### 4.1 Step 1: Prepare (app chain)

Deploy the new implementation and migrator on the app chain:

```bash
forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
```

**Important:** Note the `MIGRATOR_ADDRESS_FOR_STEP_2` from the output.

### 4.2 Step 2: SetMigrator (settlement chain)

Set the migrator in the settlement chain parameter registry (via Fireblocks):

```bash
export FIREBLOCKS_NOTE="setMigrator IdentityUpdateBroadcaster on testnet"

npx fireblocks-json-rpc --http -- \
  forge script IdentityUpdateBroadcasterUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "SetMigratorInParameterRegistry(address)" <MIGRATOR_ADDRESS> --broadcast
```

Approve the transaction in the Fireblocks console and wait for it to complete.

### 4.3 Step 3: BridgeParameter (settlement chain)

Bridge the migrator parameter to the app chain:

```bash
forge script IdentityUpdateBroadcasterUpgrader --rpc-url base_sepolia --slow --sig "BridgeParameter()" --broadcast
```

Wait for the bridge transaction to finalize. You can verify the migrator arrived on the app chain by checking the app chain parameter registry:

```bash
forge script BridgeParameter --rpc-url xmtp_ropsten --sig "get(string)" "xmtp.identityUpdateBroadcaster.migrator"
```

The `Value (address)` in the output should match the `MIGRATOR_ADDRESS` from Step 1.

### 4.4 Step 4: Upgrade (app chain)

After the bridge transaction finalizes, execute the migration on the app chain:

```bash
forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
```

The script will verify that contract state is preserved after the upgrade.

## 5. Fireblocks Local RPC

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

## 6. Post-Upgrade

After a successful upgrade:

1. Copy the new implementation address to `config/<environment>.json`
2. Verify the implementation contract:

```bash
./dev/verify-base xmtp_ropsten alchemy
```
