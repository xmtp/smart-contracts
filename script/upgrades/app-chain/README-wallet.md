# App Chain Upgrades — Wallet (Private Key)

## Table of Contents

- [1. Overview](#1-overview)
- [2. Token Requirements](#2-token-requirements)
- [3. Prerequisites](#3-prerequisites)
  - [3.1 `.env` file](#31-env-file)
  - [3.2 `config/<environment>.json`](#32-configenvironmentjson)
- [4. Upgrade Process](#4-upgrade-process)
  - [4.1 Example: Upgrade IdentityUpdateBroadcaster on testnet-dev](#41-example-upgrade-identityupdatebroadcaster-on-testnet-dev)
- [5. Post-Upgrade](#5-post-upgrade)

## 1. Overview

Use this workflow when the environment defaults to `ADMIN_PRIVATE_KEY` or when overriding to use a private key.

App chain upgrades are **always three steps** (regardless of signing method) because they span two chains.

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
ADMIN_PRIVATE_KEY=...        # Admin key for param registry (Step 2)
DEPLOYER_PRIVATE_KEY=...     # Deployer key (all steps)
BASE_SEPOLIA_RPC_URL=...     # Settlement chain RPC
XMTP_ROPSTEN_RPC_URL=...     # App chain RPC
```

### 3.2 `config/<environment>.json`

```json
{
  "factory": "0x...", // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...", // Parameter registry for setting migrator address
  "<contract>Proxy": "0x..." // The proxy being upgraded (e.g., identityUpdateBroadcasterProxy)
}
```

## 4. Upgrade Process

### 4.1 Example: Upgrade IdentityUpdateBroadcaster on testnet-dev

**Step 1: Prepare (app chain)**

```bash
ENVIRONMENT=testnet-dev forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
```

Note the `MIGRATOR_ADDRESS_FOR_STEP_2` from output.

**Step 2: Bridge (settlement chain)**

```bash
ENVIRONMENT=testnet-dev forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
```

Wait for bridge to complete. Verify on app chain parameter registry.

**Step 3: Upgrade (app chain)**

```bash
ENVIRONMENT=testnet-dev forge script IdentityUpdateBroadcasterUpgrader \
  --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
```

## 5. Post-Upgrade

1. Copy the new implementation address to `config/<environment>.json`
2. Verify:

```bash
./dev/verify-base xmtp_ropsten alchemy
```
