# Settlement Chain Parameters - Fireblocks <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1. `.env` file](#21-env-file)
  - [2.2. `config/<environment>.json`](#22-configenvironmentjson)
- [3. Setting Parameters](#3-setting-parameters)
  - [3.1. Setup Defaults](#31-setup-defaults)
  - [3.2. Set a bytes32 value](#32-set-a-bytes32-value)
  - [3.3. Set an address value](#33-set-an-address-value)
  - [3.4. Set a uint256 value](#34-set-a-uint256-value)
  - [3.5. Set a boolean value](#35-set-a-boolean-value)
- [4. Reading Parameters](#4-reading-parameters)
- [5. Fireblocks Local RPC](#5-fireblocks-local-rpc)
- [6. Next Steps](#6-next-steps)

## 1. Overview

Use this workflow to send admin transactions via the Fireblocks-managed admin address. See [environment defaults](README.md#2-environment-defaults) for when this applies.

Each parameter set operation requires approval in Fireblocks.

## 2. Prerequisites

### 2.1. `.env` file

```bash
ADMIN=...                              # Fireblocks vault account address (the admin)
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint
FIREBLOCKS_API_KEY=...                 # From Fireblocks console → Settings → API Users
FIREBLOCKS_API_PRIVATE_KEY_PATH=...    # Path to API private key file (download from 1Password)
FIREBLOCKS_VAULT_ACCOUNT_IDS=...       # Vault account ID that owns the ADMIN address
```

### 2.2. `config/<environment>.json`

Ensure the following field is defined correctly for your chosen environment:

```json
{
  "parameterRegistryProxy": "0x..." // Settlement chain parameter registry address
}
```

## 3. Setting Parameters

### 3.1. Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
export ADMIN_ADDRESS_TYPE=FIREBLOCKS   # use Fireblocks signing
export FIREBLOCKS_NOTE="set xmtp.example.key on testnet"  # description shown in Fireblocks approval
export FIREBLOCKS_EXTERNAL_TX_ID="setParam-$(date +%s)"   # idempotency key to prevent duplicate Fireblocks transactions
```

### 3.2. Set a bytes32 value

Use this for raw bytes32 values:

```bash
npx fireblocks-json-rpc --http -- \
  forge script SetParameter --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "set(string,bytes32)" "xmtp.example.key" 0x0000000000000000000000000000000000000000000000000000000000000001 --broadcast
```

Approve the transaction in Fireblocks.

### 3.3. Set an address value

Use this for address parameters (automatically right-justified to bytes32):

```bash
npx fireblocks-json-rpc --http -- \
  forge script SetParameter --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "setAddress(string,address)" "xmtp.nodeRegistry.admin" 0x1234567890123456789012345678901234567890 --broadcast
```

Approve the transaction in Fireblocks.

### 3.4. Set a uint256 value

Use this for numeric parameters (automatically converted to bytes32):

```bash
npx fireblocks-json-rpc --http -- \
  forge script SetParameter --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "setUint(string,uint256)" "xmtp.nodeRegistry.maxCanonicalNodes" 100 --broadcast
```

Approve the transaction in Fireblocks.

### 3.5. Set a boolean value

Use this for boolean parameters (encoded as 1 for true, 0 for false):

```bash
npx fireblocks-json-rpc --http -- \
  forge script SetParameter --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "setBool(string,bool)" "xmtp.groupMessageBroadcaster.paused" true --broadcast
```

Approve the transaction in Fireblocks.

## 4. Reading Parameters

To read the current value of a parameter (no transaction or Fireblocks approval required):

```bash
forge script SetParameter --rpc-url base_sepolia \
  --sig "get(string)" "xmtp.nodeRegistry.maxCanonicalNodes"
```

This will display the value in multiple formats: bytes32, uint256, and address.

## 5. Fireblocks Local RPC

The Fireblocks JSON-RPC proxy runs locally and redirects signing requests to Fireblocks.

When you see `npx fireblocks-json-rpc --http --`, it:

1. Starts a local RPC server
2. Executes the forge command
3. Routes signing requests to Fireblocks for approval
4. Shuts down after the command completes

| Flag              | Purpose                                                                          |
| ----------------- | -------------------------------------------------------------------------------- |
| `--rpc-url {}`    | The local RPC injects its URL in place of `{}`                                   |
| `--sender $ADMIN` | Specifies the Fireblocks-managed address for the transaction                     |
| `--unlocked`      | Indicates the sender address is managed externally                               |
| `--timeout 3600`  | Wait up to 1 hour for Fireblocks approval (prevents early abort)                 |
| `--retries 1`     | Minimal retries (forge minimum); `FIREBLOCKS_EXTERNAL_TX_ID` prevents duplicates |

## 6. Next Steps

After setting a parameter on the settlement chain, you may need to bridge it to the app chain. See `script/parameters/app-chain/README.md` for bridging instructions.
