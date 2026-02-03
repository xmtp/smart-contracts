# Settlement Chain Parameters — Wallet (Private Key)

## Table of Contents

- [Settlement Chain Parameters — Wallet (Private Key)](#settlement-chain-parameters--wallet-private-key)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Prerequisites](#2-prerequisites)
    - [2.1 `.env` file](#21-env-file)
    - [2.2 `config/<environment>.json`](#22-configenvironmentjson)
  - [3. Setting Parameters](#3-setting-parameters)
    - [3.1 Set a bytes32 value](#31-set-a-bytes32-value)
    - [3.2 Set an address value](#32-set-an-address-value)
    - [3.3 Set a uint256 value](#33-set-a-uint256-value)
    - [3.4 Set a boolean value](#34-set-a-boolean-value)
  - [4. Reading Parameters](#4-reading-parameters)
  - [5. Next Steps](#5-next-steps)

## 1. Overview

Use this workflow when the [environment defaults](README.md#2-environment-defaults) to `ADMIN_PRIVATE_KEY` or when overriding to use a private key.

This is the simpler workflow — no Fireblocks approval required.

## 2. Prerequisites

### 2.1 `.env` file

```bash
ADMIN_PRIVATE_KEY=...        # Admin private key (must be a parameter registry admin)
BASE_SEPOLIA_RPC_URL=...     # Settlement chain RPC endpoint
```

### 2.2 `config/<environment>.json`

Ensure the following field is defined correctly for your chosen environment:

```json
{
  "parameterRegistryProxy": "0x..." // Settlement chain parameter registry address
}
```

## 3. Setting Parameters

### 3.1 Set a bytes32 value

Use this for raw bytes32 values:

```bash
ENVIRONMENT=testnet-dev forge script SetParameter \
  --rpc-url base_sepolia \
  --slow \
  --sig "set(string,bytes32)" "xmtp.example.key" 0x0000000000000000000000000000000000000000000000000000000000000001 \
  --broadcast
```

### 3.2 Set an address value

Use this for address parameters (automatically right-justified to bytes32):

```bash
ENVIRONMENT=testnet-dev forge script SetParameter \
  --rpc-url base_sepolia \
  --slow \
  --sig "setAddress(string,address)" "xmtp.nodeRegistry.admin" 0x1234567890123456789012345678901234567890 \
  --broadcast
```

### 3.3 Set a uint256 value

Use this for numeric parameters (automatically converted to bytes32):

```bash
ENVIRONMENT=testnet-dev forge script SetParameter \
  --rpc-url base_sepolia \
  --slow \
  --sig "setUint(string,uint256)" "xmtp.nodeRegistry.maxCanonicalNodes" 100 \
  --broadcast
```

### 3.4 Set a boolean value

Use this for boolean parameters (encoded as 1 for true, 0 for false):

```bash
ENVIRONMENT=testnet-dev forge script SetParameter \
  --rpc-url base_sepolia \
  --slow \
  --sig "setBool(string,bool)" "xmtp.groupMessageBroadcaster.paused" true \
  --broadcast
```

**Overriding to private key on testnet:**

If testnet defaults to Fireblocks but you want to use a private key:

```bash
ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=PRIVATE_KEY forge script SetParameter \
  --rpc-url base_sepolia \
  --slow \
  --sig "setUint(string,uint256)" "xmtp.example.key" 42 \
  --broadcast
```

## 4. Reading Parameters

To read the current value of a parameter (no transaction required, view-only):

```bash
ENVIRONMENT=testnet-dev forge script SetParameter \
  --rpc-url base_sepolia \
  --sig "get(string)" "xmtp.nodeRegistry.maxCanonicalNodes"
```

This will display the value in multiple formats: bytes32, uint256, and address.

## 5. Next Steps

After setting a parameter on the settlement chain, you may need to bridge it to the app chain. See `script/parameters/app-chain/README.md` for bridging instructions.
