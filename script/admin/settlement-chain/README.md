# Node Registry Admin <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Environment Defaults](#2-environment-defaults)
- [3. Choose Your Workflow](#3-choose-your-workflow)

## 1. Overview

This folder contains scripts for calling admin functions on the NodeRegistry contract.

These operations require **NodeRegistry admin privileges** (the admin is set via the parameter registry key `xmtp.nodeRegistry.admin`).

Available admin operations:

| Function            | Description                              |
| ------------------- | ---------------------------------------- |
| `addNode`           | Add a new node and mint its NFT          |
| `addToNetwork`      | Add a node to the canonical network      |
| `removeFromNetwork` | Remove a node from the canonical network |
| `setBaseURI`        | Set the base URI for node NFTs           |

Available view operations (no transaction required):

| Function            | Description                     |
| ------------------- | ------------------------------- |
| `getAllNodes`       | List all nodes in the registry  |
| `getCanonicalNodes` | List all canonical node IDs     |
| `getNode`           | Get details for a specific node |
| `getAdmin`          | Get the current admin address   |

## 2. Environment Defaults

| Environment       | Default      | To Override                     |
| ----------------- | ------------ | ------------------------------- |
| `testnet-dev`     | `WALLET`     | `ADMIN_ADDRESS_TYPE=FIREBLOCKS` |
| `testnet-staging` | `WALLET`     | `ADMIN_ADDRESS_TYPE=FIREBLOCKS` |
| `testnet`         | `FIREBLOCKS` | `ADMIN_ADDRESS_TYPE=WALLET`     |
| `mainnet`         | `FIREBLOCKS` | No override possible            |

Add the override variable to your command when you need to use the non-default signing method.

## 3. Choose Your Workflow

- **[README-wallet.md](README-wallet.md)** - Private key signing (simpler, single-step process)
- **[README-fireblocks.md](README-fireblocks.md)** - Fireblocks signing (requires Fireblocks approval)
