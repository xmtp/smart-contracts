# App Chain Upgrades — Fireblocks

## Table of Contents

- [1. Overview](#1-overview)
- [2. Token Requirements](#2-token-requirements)
- [3. Prerequisites](#3-prerequisites)
  - [3.1 `.env` file](#31-env-file)
  - [3.2 `config/<environment>.json`](#32-configenvironmentjson)
- [4. Upgrade Process](#4-upgrade-process)
  - [4.1 Prepare (app chain)](#41-prepare-app-chain)
  - [4.2 Bridge (settlement chain, via Fireblocks)](#42-bridge-settlement-chain-via-fireblocks)
  - [4.3 Upgrade (app chain)](#43-upgrade-app-chain)
- [5. Fireblocks CLI Flags](#5-fireblocks-cli-flags)
- [6. Post-Upgrade](#6-post-upgrade)

## 1. Overview

Use this workflow when the environment defaults to `FIREBLOCKS` or when overriding to use Fireblocks.

App chain upgrades are **always three steps** because they span two chains. Only **Step 2** (the admin tx) routes through Fireblocks.

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
DEPLOYER_PRIVATE_KEY=...     # Deployer key (all steps)
ADMIN=...                    # Fireblocks vault account address
BASE_SEPOLIA_RPC_URL=...     # Settlement chain RPC
XMTP_ROPSTEN_RPC_URL=...     # App chain RPC

# Fireblocks configuration (see .env.template)
FIREBLOCKS_API_KEY=...
FIREBLOCKS_API_PRIVATE_KEY_PATH=...
FIREBLOCKS_VAULT_ACCOUNT_IDS=...
# FIREBLOCKS_NOTE is auto-generated if omitted
```

### 3.2 `config/<environment>.json`

```json
{
  "factory": "0x...",                    // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...",     // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..."             // The proxy being upgraded (e.g., identityUpdateBroadcasterProxy)
}
```

## 4. Upgrade Process

| Step | Function    | Chain      | Signer   | Fireblocks? |
| ---- | ----------- | ---------- | -------- | ----------- |
| 1    | `Prepare()` | App        | DEPLOYER | No          |
| 2    | `Bridge()`  | Settlement | ADMIN    | **Yes**     |
| 3    | `Upgrade()` | App        | DEPLOYER | No          |

As a worked example, the below does an upgrade of `IdentityUpdateBroadcaster` on `testnet`.

### 4.1 Prepare (app chain)

```bash
ENVIRONMENT=testnet ADMIN=$ADMIN forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
```

Note the `MIGRATOR_ADDRESS_FOR_STEP_2` from output.

### 4.2 Bridge (settlement chain, via Fireblocks)

```bash
export FIREBLOCKS_NOTE="bridge IdentityUpdateBroadcaster on testnet"

ENVIRONMENT=testnet npx fireblocks-json-rpc --http -- \
  forge script IdentityUpdateBroadcasterUpgrader \
  --sender $ADMIN --slow --unlocked --rpc-url {} \
  --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
```

Approve the transaction in the Fireblocks dashboard. Wait for bridge to complete.

### 4.3 Upgrade (app chain)

```bash
ENVIRONMENT=testnet ADMIN=$ADMIN forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
```

## 5. Fireblocks CLI Flags

When using `npx fireblocks-json-rpc --http --`:

| Flag | Purpose |
| ---- | ------- |
| `--rpc-url {}` | Proxy replaces `{}` with its URL |
| `--sender $ADMIN` | Address to sign via Fireblocks |
| `--unlocked` | Indicates sender is externally managed |

## 6. Post-Upgrade

1. Copy the new implementation address to `config/<environment>.json`
2. Verify:

```bash
./dev/verify-base xmtp_ropsten alchemy
```
