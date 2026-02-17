# Node Registry Admin - Wallet (Private Key) <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1. `.env` file](#21-env-file)
  - [2.2. `config/<environment>.json`](#22-configenvironmentjson)
- [3. Admin Operations](#3-admin-operations)
  - [3.1. Setup Defaults](#31-setup-defaults)
  - [3.2. Add a Node](#32-add-a-node)
  - [3.3. Add a Node to the Canonical Network](#33-add-a-node-to-the-canonical-network)
  - [3.4. Remove a Node from the Canonical Network](#34-remove-a-node-from-the-canonical-network)
  - [3.5. Set Base URI](#35-set-base-uri)

## 1. Overview

Use this workflow to send admin transactions via `NODE_REGISTRY_ADMIN_PRIVATE_KEY`. See [environment defaults](README.md#2-environment-defaults) for when this applies.

## 2. Prerequisites

### 2.1. `.env` file

```bash
NODE_REGISTRY_ADMIN_PRIVATE_KEY=...  # NodeRegistry admin private key
BASE_SEPOLIA_RPC_URL=...             # Settlement chain RPC endpoint
```

### 2.2. `config/<environment>.json`

Ensure the following field is defined correctly for your chosen environment:

```json
{
  "nodeRegistryProxy": "0x..." // NodeRegistry proxy address
}
```

## 3. Admin Operations

### 3.1. Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet-dev         # or: testnet-staging, testnet, mainnet
export ADMIN_ADDRESS_TYPE=WALLET       # use wallet private key signing
```

### 3.2. Add a Node

Adds a new node to the registry. Requires the owner address, a 65-byte uncompressed signing public key (`0x04` + 32 bytes X + 32 bytes Y), and an HTTP address.

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "addNode(address,bytes,string)" \
  <OWNER_ADDRESS> \
  <SIGNING_PUBLIC_KEY> \
  <HTTP_ADDRESS> \
  --broadcast
```

Example:

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "addNode(address,bytes,string)" \
  0x1234567890123456789012345678901234567890 \
  0x0412345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678ff \
  "https://node1.example.com:5050" \
  --broadcast
```

The script outputs the assigned **Node ID** and the derived **Signer** address.

### 3.3. Add a Node to the Canonical Network

Adds an existing node to the canonical network:

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "addToNetwork(uint32)" <NODE_ID> --broadcast
```

Example:

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "addToNetwork(uint32)" 100 --broadcast
```

### 3.4. Remove a Node from the Canonical Network

Removes a node from the canonical network (the node still exists but is no longer canonical):

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "removeFromNetwork(uint32)" <NODE_ID> --broadcast
```

Example:

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "removeFromNetwork(uint32)" 100 --broadcast
```

### 3.5. Set Base URI

Sets the base URI for node NFT metadata. The URI must end with a trailing slash:

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "setBaseURI(string)" <BASE_URI> --broadcast
```

Example:

```bash
forge script NodeRegistryAdmin --rpc-url base_sepolia --slow \
  --sig "setBaseURI(string)" "https://metadata.xmtp.org/nodes/" --broadcast
```
