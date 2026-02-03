# App Chain Upgrades — Wallet (Private Key)

## Table of Contents

- [App Chain Upgrades — Wallet (Private Key)](#app-chain-upgrades--wallet-private-key)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Token Requirements](#2-token-requirements)
  - [3. Prerequisites](#3-prerequisites)
    - [3.1 `.env` file](#31-env-file)
    - [3.2 `config/<environment>.json`](#32-configenvironmentjson)
  - [4. Upgrade Process (Three Steps)](#4-upgrade-process-three-steps)
    - [4.0 Setup Defaults](#40-setup-defaults)
    - [4.1 Step 1: Prepare (app chain)](#41-step-1-prepare-app-chain)
    - [4.2 Step 2: Bridge (settlement chain)](#42-step-2-bridge-settlement-chain)
    - [4.3 Step 3: Upgrade (app chain)](#43-step-3-upgrade-app-chain)
  - [5. Post-Upgrade](#5-post-upgrade)

## 1. Overview

Use this workflow to send admin transactions via `ADMIN_PRIVATE_KEY`. See [environment defaults](README.md#2-environment-defaults) for when this applies.

App chain upgrades are **always three steps** (regardless of signing method) because they span two chains. The migrator address must be bridged from the settlement chain to the app chain.

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
ADMIN_PRIVATE_KEY=...        # Admin private key (for setting migrator in Step 2)
BASE_SEPOLIA_RPC_URL=...     # Settlement chain RPC endpoint
DEPLOYER_PRIVATE_KEY=...     # Deployer private key (for all steps)
XMTP_ROPSTEN_RPC_URL=...     # App chain RPC endpoint
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

The following example upgrades `IdentityUpdateBroadcaster` on `testnet-dev`.

### 4.0 Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet-dev         # or: testnet-staging, testnet, mainnet
export ADMIN_ADDRESS_TYPE=WALLET       # use wallet private key signing
```

### 4.1 Step 1: Prepare (app chain)

Deploy the new implementation and migrator on the app chain:

```bash
forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow \
  --sig "Prepare()" --broadcast
```

**Important:** Note the `MIGRATOR_ADDRESS_FOR_STEP_2` from the output.

### 4.2 Step 2: Bridge (settlement chain)

Set the migrator in the settlement chain parameter registry and bridge it to the app chain:

```bash
forge script IdentityUpdateBroadcasterUpgrader --rpc-url base_sepolia --slow \
  --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
```

Wait for the bridge transaction to finalize. You can verify the migrator arrived on the app chain by checking the app chain parameter registry.

### 4.3 Step 3: Upgrade (app chain)

Execute the migration on the app chain:

```bash
forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow \
  --sig "Upgrade()" --broadcast
```

The script will verify that contract state is preserved after the upgrade.

## 5. Post-Upgrade

After a successful upgrade:

1. Copy the new implementation address to `config/<environment>.json`
2. Verify the implementation contract:

```bash
./dev/verify-base xmtp_ropsten alchemy
```
