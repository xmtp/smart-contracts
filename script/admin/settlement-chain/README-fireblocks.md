# Node Registry Admin - Fireblocks <!-- omit from toc -->

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
- [4. View Operations](#4-view-operations)
- [5. Fireblocks Local RPC](#5-fireblocks-local-rpc)

## 1. Overview

Use this workflow to send admin transactions via the Fireblocks-managed admin address. See [environment defaults](README.md#2-environment-defaults) for when this applies.

Each admin operation requires approval in Fireblocks.

## 2. Prerequisites

### 2.1. `.env` file

```bash
NODE_REGISTRY_ADMIN_ADDRESS=...        # Fireblocks vault account address (the NodeRegistry admin)
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint
FIREBLOCKS_API_KEY=...                 # From Fireblocks console → Settings → API Users
FIREBLOCKS_API_PRIVATE_KEY_PATH=...    # Path to API private key file (download from 1Password)
FIREBLOCKS_VAULT_ACCOUNT_IDS=...       # List must include the vault account ID that owns the NODE_REGISTRY_ADMIN_ADDRESS
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
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
export ADMIN_ADDRESS_TYPE=FIREBLOCKS   # use Fireblocks signing
```

### 3.2. Add a Node

Adds a new node to the registry. Requires the owner address, a 65-byte uncompressed signing public key (`0x04` + 32 bytes X + 32 bytes Y), and an HTTP address.

```bash
export FIREBLOCKS_NOTE="addNode to NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "addNode(address,bytes,string)" \
  <OWNER_ADDRESS> \
  <SIGNING_PUBLIC_KEY> \
  <HTTP_ADDRESS> \
  --broadcast
```

Example:

```bash
export FIREBLOCKS_NOTE="addNode to NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "addNode(address,bytes,string)" \
  0x1234567890123456789012345678901234567890 \
  0x0412345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678ff \
  "https://node1.example.com:5050" \
  --broadcast
```

Approve the transaction in Fireblocks. The script outputs the assigned **Node ID** and the derived **Signer** address.

### 3.3. Add a Node to the Canonical Network

Adds an existing node to the canonical network (makes it active for consensus):

```bash
export FIREBLOCKS_NOTE="addToNetwork on NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "addToNetwork(uint32)" <NODE_ID> --broadcast
```

Example:

```bash
export FIREBLOCKS_NOTE="addToNetwork node 100 on NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "addToNetwork(uint32)" 100 --broadcast
```

Approve the transaction in Fireblocks.

### 3.4. Remove a Node from the Canonical Network

Removes a node from the canonical network (the node still exists but is no longer canonical):

```bash
export FIREBLOCKS_NOTE="removeFromNetwork on NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "removeFromNetwork(uint32)" <NODE_ID> --broadcast
```

Example:

```bash
export FIREBLOCKS_NOTE="removeFromNetwork node 100 on NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "removeFromNetwork(uint32)" 100 --broadcast
```

Approve the transaction in Fireblocks.

### 3.5. Set Base URI

Sets the base URI for node NFT metadata. The URI must end with a trailing slash:

```bash
export FIREBLOCKS_NOTE="setBaseURI on NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "setBaseURI(string)" <BASE_URI> --broadcast
```

Example:

```bash
export FIREBLOCKS_NOTE="setBaseURI on NodeRegistry on $ENVIRONMENT"
export FIREBLOCKS_EXTERNAL_TX_ID=$(uuidgen)  # idempotency key, re-run before each new Fireblocks command

npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryAdmin --sender $NODE_REGISTRY_ADMIN_ADDRESS --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 \
  --sig "setBaseURI(string)" "https://metadata.xmtp.org/nodes/" --broadcast
```

Approve the transaction in Fireblocks.

## 4. View Operations

View operations are read-only and do not require a transaction or Fireblocks approval. Use the same commands as the [wallet workflow](README-wallet.md#4-view-operations).

```bash
# Get all nodes
forge script NodeRegistryAdmin --rpc-url base_sepolia --sig "getAllNodes()"

# Get canonical nodes
forge script NodeRegistryAdmin --rpc-url base_sepolia --sig "getCanonicalNodes()"

# Get a specific node
forge script NodeRegistryAdmin --rpc-url base_sepolia --sig "getNode(uint32)" <NODE_ID>

# Get the current admin address
forge script NodeRegistryAdmin --rpc-url base_sepolia --sig "getAdmin()"
```

## 5. Fireblocks Local RPC

The Fireblocks JSON-RPC proxy runs locally and redirects signing requests to Fireblocks.

When you see `npx fireblocks-json-rpc --http --`, it:

1. Starts a local RPC server
2. Executes the forge command
3. Routes signing requests to Fireblocks for approval
4. Shuts down after the command completes

| Flag                                    | Purpose                                                                          |
| --------------------------------------- | -------------------------------------------------------------------------------- |
| `--rpc-url {}`                          | The local RPC injects its URL in place of `{}`                                   |
| `--sender $NODE_REGISTRY_ADMIN_ADDRESS` | Specifies the Fireblocks-managed NodeRegistry admin address                      |
| `--unlocked`                            | Indicates the sender address is managed externally                               |
| `--timeout 14400`                       | Wait up to 4 hours for Fireblocks approval (prevents early abort)                |
| `--retries 1`                           | Minimal retries (forge minimum); `FIREBLOCKS_EXTERNAL_TX_ID` prevents duplicates |

> **If forge times out:** Don't panic. The Fireblocks transaction will continue processing independently. Check the Fireblocks console to confirm the transaction was approved and completed on-chain. If it was, you're done. If you need to re-run, generate a new `FIREBLOCKS_EXTERNAL_TX_ID` (via `uuidgen`) to avoid idempotency conflicts with the completed transaction.
