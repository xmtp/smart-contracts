# App Chain Upgrades — Fireblocks

## Table of Contents

- [App Chain Upgrades — Fireblocks](#app-chain-upgrades--fireblocks)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Token Requirements](#2-token-requirements)
  - [3. Prerequisites](#3-prerequisites)
    - [3.1 `.env` file](#31-env-file)
    - [3.2 `config/<environment>.json`](#32-configenvironmentjson)
  - [4. Upgrade Process (Three Steps)](#4-upgrade-process-three-steps)
    - [4.1 Step 1: Prepare (app chain)](#41-step-1-prepare-app-chain)
    - [4.2 Step 2: Bridge (settlement chain, via Fireblocks)](#42-step-2-bridge-settlement-chain-via-fireblocks)
    - [4.3 Step 3: Upgrade (app chain)](#43-step-3-upgrade-app-chain)
  - [5. Fireblocks Local RPC](#5-fireblocks-local-rpc)
  - [6. Post-Upgrade](#6-post-upgrade)

## 1. Overview

Use this workflow when the [environment defaults](README.md#2-environment-defaults) to Fireblocks or when overriding to use Fireblocks.

App chain upgrades are **always three steps** because they span two chains. Only **Step 2** (setting and bridging the migrator) routes through Fireblocks signing.

## 2. Token Requirements

| Step       | Chain      | Address  | baseETH | xUSD (settlement) | xUSD (app) |
| ---------- | ---------- | -------- | ------- | ----------------- | ---------- |
| 1. Prepare | App        | DEPLOYER | —       | —                 | Yes        |
| 2. Bridge  | Settlement | ADMIN    | Yes     | —                 | —          |
| 2. Bridge  | Settlement | DEPLOYER | Yes     | Yes               | —          |
| 3. Upgrade | App        | DEPLOYER | —       | —                 | Yes        |

## 3. Prerequisites

### 3.1 `.env` file

```bash
ADMIN=...                              # Fireblocks vault account address (the admin)
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

## 4. Upgrade Process (Three Steps)

| Step | Function    | Chain      | Signer   | Fireblocks? |
| ---- | ----------- | ---------- | -------- | ----------- |
| 1    | `Prepare()` | App        | DEPLOYER | No          |
| 2    | `Bridge()`  | Settlement | ADMIN    | **Yes**     |
| 3    | `Upgrade()` | App        | DEPLOYER | No          |

The following example upgrades `IdentityUpdateBroadcaster` on `testnet`.

### 4.1 Step 1: Prepare (app chain)

Deploy the new implementation and migrator on the app chain:

```bash
ENVIRONMENT=testnet ADMIN=$ADMIN forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url xmtp_ropsten \
  --slow \
  --sig "Prepare()" \
  --broadcast
```

**Important:** Note the `MIGRATOR_ADDRESS_FOR_STEP_2` from the output.

### 4.2 Step 2: Bridge (settlement chain, via Fireblocks)

Set the migrator in the settlement chain parameter registry and bridge it to the app chain:

```bash
export FIREBLOCKS_NOTE="bridge IdentityUpdateBroadcaster on testnet"

ENVIRONMENT=testnet npx fireblocks-json-rpc --http -- \
  forge script IdentityUpdateBroadcasterUpgrader \
  --sender $ADMIN \
  --slow \
  --unlocked \
  --rpc-url {} \
  --sig "Bridge(address)" <MIGRATOR_ADDRESS> \
  --broadcast
```

Approve the transaction in the Fireblocks dashboard, then wait for the bridge to complete.

### 4.3 Step 3: Upgrade (app chain)

After the bridge transaction finalizes, execute the migration on the app chain:

```bash
ENVIRONMENT=testnet ADMIN=$ADMIN forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url xmtp_ropsten \
  --slow \
  --sig "Upgrade()" \
  --broadcast
```

The script will verify that contract state is preserved after the upgrade.

## 5. Fireblocks Local RPC

The Fireblocks JSON-RPC proxy runs locally and redirects signing requests to Fireblocks.

When you see `npx fireblocks-json-rpc --http --`, it:

1. Starts a local RPC server
2. Executes the forge command
3. Routes signing requests to Fireblocks for approval
4. Shuts down after the command completes

| Flag              | Purpose                                                      |
| ----------------- | ------------------------------------------------------------ |
| `--rpc-url {}`    | The local RPC injects its URL in place of `{}`               |
| `--sender $ADMIN` | Specifies the Fireblocks-managed address for the transaction |
| `--unlocked`      | Indicates the sender address is managed externally           |

## 6. Post-Upgrade

After a successful upgrade:

1. Copy the new implementation address to `config/<environment>.json`
2. Verify the implementation contract:

```bash
./dev/verify-base xmtp_ropsten alchemy
```
