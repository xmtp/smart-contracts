# Settlement Chain Single Deployments - Fireblocks <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Prerequisites](#2-prerequisites)
  - [2.1. `.env` file](#21-env-file)
  - [2.2. `config/<environment>.json`](#22-configenvironmentjson)
- [3. Deployment Process (Four Steps)](#3-deployment-process-four-steps)
  - [3.1. Setup Defaults](#31-setup-defaults)
  - [3.2. Step 1: Predict Addresses](#32-step-1-predict-addresses)
  - [3.3. Step 2: Deploy Contract](#33-step-2-deploy-contract)
  - [3.4. Step 3: Set Parameter Registry Values (Fireblocks)](#34-step-3-set-parameter-registry-values-fireblocks)
  - [3.5. Step 4: Update Contract Dependencies](#35-step-4-update-contract-dependencies)
- [4. Fireblocks Local RPC](#4-fireblocks-local-rpc)
- [5. Post-Deployment](#5-post-deployment)

## 1. Overview

Use this workflow to deploy new contracts via the Fireblocks-managed admin address. See [environment defaults](README.md#2-environment-defaults) for when this applies.

Fireblocks requires a **multi-step process** because only Step 3 (setting parameter registry values) routes through Fireblocks signing. Steps 1, 2, and 4 use the deployer key directly.

A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract. Dependencies are managed through the parameter registry and must be updated after deployment.

**Important:** Contract deployment (Step 2) does NOT require admin privileges. The newly deployed contract's initial state is set via constructor/initializer parameters. Admin privileges (via Fireblocks) are ONLY required for Step 3 (setting parameter registry values) so that other contracts can update their references to point to the new contract.

## 2. Prerequisites

### 2.1. `.env` file

```bash
ADMIN=...                              # Fireblocks vault account address
BASE_SEPOLIA_RPC_URL=...               # Settlement chain RPC endpoint
DEPLOYER_PRIVATE_KEY=...               # Deployer private key (for Steps 1, 2, and 4)
ETHERSCAN_API_KEY=...                  # For contract verification
ETHERSCAN_API_URL=https://api-sepolia.basescan.org/api
FIREBLOCKS_API_KEY=...                 # From Fireblocks console → Settings → API Users
FIREBLOCKS_API_PRIVATE_KEY_PATH=...    # Path to API private key file (download from 1Password)
FIREBLOCKS_VAULT_ACCOUNT_IDS=...       # Vault account ID that owns the ADMIN address
```

### 2.2. `config/<environment>.json`

Ensure the following fields are defined correctly for your chosen environment:

```json
{
  "factory": "0x...", // Factory contract for creating new contracts
  "parameterRegistryProxy": "0x...", // Parameter registry for setting values
  "deployer": "0x...", // Deployer address
  "<contract>ProxySalt": "0x...", // Salt for deterministic proxy deployment
  "<contract>Implementation": "0x...", // Expected implementation address
  "<contract>Proxy": "0x..." // Expected proxy address
}
```

## 3. Deployment Process (Four Steps)

| Step | Function                       | Signer   | Fireblocks? |
| ---- | ------------------------------ | -------- | ----------- |
| 1    | `predictAddresses()`           | N/A      | No          |
| 2    | `deployContract()`             | DEPLOYER | No          |
| 3    | `SetParameterRegistryValues()` | ADMIN    | **Yes**     |
| 4    | `UpdateContractDependencies()` | DEPLOYER | No          |

The following example deploys `PayerReportManager` on `testnet`.

### 3.1. Setup Defaults

Before running any commands, set these environment variables:

```bash
export ENVIRONMENT=testnet             # or: testnet-dev, testnet-staging, mainnet
export ADMIN_ADDRESS_TYPE=FIREBLOCKS   # use Fireblocks signing
```

### 3.2. Step 1: Predict Addresses

Calculate the deterministic addresses that will be deployed:

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --sig "predictAddresses()"
```

**Important:** Copy the predicted addresses to `config/<environment>.json`:

- `Implementation` address
- `Proxy` address

### 3.3. Step 2: Deploy Contract

Deploy the new implementation and proxy:

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

This will:

1. Deploy the implementation contract
2. Deploy the proxy contract
3. Initialize the proxy
4. Update `environments/<environment>.json` with the proxy address

### 3.4. Step 3: Set Parameter Registry Values (Fireblocks)

Set the required parameters in the parameter registry (via Fireblocks):

```bash
export FIREBLOCKS_NOTE="Deploy PayerReportManager on testnet"

npx fireblocks-json-rpc --http -- \
  forge script DeployPayerReportManagerScript --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 \
  --sig "SetParameterRegistryValues()" --broadcast
```

Approve the transaction in the Fireblocks console and wait for it to complete.

This sets parameters like:

- `xmtp.payerRegistry.settler` (for PayerReportManager)
- `xmtp.payerRegistry.feeDistributor` (for DistributionManager)

**Note:** For NodeRegistry, this step is informational only. Parameters must be set manually via the `SetParameter` script before proceeding to the next step.

### 3.5. Step 4: Update Contract Dependencies

Update dependent contracts to read the new parameter values:

```bash
forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "UpdateContractDependencies()" --broadcast
```

This calls permissionless update functions like:

- `PayerRegistry.updateSettler()`
- `PayerRegistry.updateFeeDistributor()`
- `NodeRegistry.updateAdmin()`
- `NodeRegistry.updateMaxCanonicalNodes()`

## 4. Fireblocks Local RPC

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

## 5. Post-Deployment

After a successful deployment:

1. Verify the implementation contract on the block explorer:

```bash
forge verify-contract --chain-id 84532 <impl-address> src/settlement-chain/PayerReportManager.sol:PayerReportManager
```

2. Verify the proxy and implementation addresses in `config/<environment>.json` and `environments/<environment>.json` match your expectations.

3. Test the deployed contract to ensure it's working correctly.
