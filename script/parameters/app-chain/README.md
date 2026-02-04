# App Chain Parameters

## Table of Contents

- [App Chain Parameters](#app-chain-parameters)
  - [Table of Contents](#table-of-contents)
  - [1. Overview](#1-overview)
  - [2. Workflow Summary](#2-workflow-summary)
  - [3. Prerequisites](#3-prerequisites)
    - [3.1 `.env` file](#31-env-file)
    - [3.2 `config/<environment>.json`](#32-configenvironmentjson)
  - [4. Bridging Parameters](#4-bridging-parameters)
    - [4.1 Using the helper script](#41-using-the-helper-script)
    - [4.2 Using forge directly](#42-using-forge-directly)
    - [4.3 Verifying the parameter arrived](#43-verifying-the-parameter-arrived)
    - [4.4 Troubleshooting](#44-troubleshooting)

## 1. Overview

This folder contains scripts for bridging parameters from the Settlement Chain Parameter Registry to the App Chain Parameter Registry.

Bridging is **permissionless** - anyone with fee tokens can bridge parameters. No admin signature or Fireblocks approval is required for the bridge step itself.

## 2. Workflow Summary

Setting a parameter on the app chain is a two-step process:

| Step | Action              | Location                             | Admin Required?               |
| ---- | ------------------- | ------------------------------------ | ----------------------------- |
| 1    | Set parameter value | Settlement chain param registry      | **Yes** (may need Fireblocks) |
| 2    | Bridge parameter    | Settlement chain gateway → App chain | No (permissionless)           |

**Step 1** is documented in `script/parameters/settlement-chain/` and may require Fireblocks approval depending on your environment.

**Step 2** (this folder) only requires DEPLOYER with fee tokens - no admin signature needed.

## 3. Prerequisites

### 3.1 `.env` file

```bash
BASE_SEPOLIA_RPC_URL=...     # Settlement chain RPC endpoint
DEPLOYER_PRIVATE_KEY=...     # Deployer private key (must have fee tokens for bridging)
```

### 3.2 `config/<environment>.json`

Ensure the following fields are defined correctly for your chosen environment:

```json
{
  "gatewayProxy": "0x...", // Settlement chain gateway address
  "feeTokenProxy": "0x...", // Fee token contract address
  "appChainId": 12345, // Target app chain ID
  "settlementChainId": 84532 // Settlement chain ID (e.g., Base Sepolia)
}
```

## 4. Bridging Parameters

### 4.1 Using the helper script

The easiest way to bridge a parameter is using the helper script:

```bash
./dev/bridge-parameter <environment> <parameter-key>
```

**Example:**

```bash
./dev/bridge-parameter testnet-dev xmtp.groupMessageBroadcaster.paused
```

### 4.2 Using forge directly

Alternatively, use forge to call the script like this:

```bash
ENVIRONMENT=testnet-dev forge script BridgeParameter \
  --rpc-url base_sepolia \
  --slow \
  --sig "push(string)" "xmtp.groupMessageBroadcaster.paused" \
  --broadcast
```

The script will:

1. Calculate the gas cost for bridging
2. Check that DEPLOYER has sufficient fee tokens
3. Approve the fee token transfer
4. Call `sendParameters()` on the Settlement Chain Gateway
5. The parameter value will arrive on the app chain after bridge finalization

### 4.3 Verifying the parameter arrived

After bridging, you can verify the parameter arrived on the app chain. Note that bridge finalization takes a few minutes.

```bash
ENVIRONMENT=testnet-dev forge script BridgeParameter \
  --rpc-url xmtp_ropsten \
  --sig "get(string)" "xmtp.groupMessageBroadcaster.paused"
```

This will display the value in multiple formats: bytes32, uint256, and address.

**Expected output:**

- `0x0000...0001` = true (for boolean parameters)
- `0x0000...0000` = false, or parameter not yet bridged

### 4.4 Troubleshooting
- If you see the L# app chain parameter value as not changed or all zeros, wait a few minutes and try again. The bridge may still be finalizing.
- If you've used a very long key, it is possible there is not enough gas for the bridge message to execute on L3. This manifests itself as failed transactions visible in the `AppChainGateway` contract on L3, but they may not show a useful error message. The clue is that the consumed gas is very close to the gas limit of the transaction.