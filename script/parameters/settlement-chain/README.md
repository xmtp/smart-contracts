# Settlement Chain Parameters <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Environment Defaults](#2-environment-defaults)
- [3. Choose Your Workflow](#3-choose-your-workflow)

## 1. Overview

This folder contains scripts for setting parameters in the Settlement Chain Parameter Registry.

Setting parameters requires **admin privileges**. The admin address can be controlled:

1. **By a local private key** - simpler, used for development environments
2. **By Fireblocks** - multi-sig approval, used for testnet and mainnet

After setting a parameter on the settlement chain, you can bridge it to the app chain using the scripts in `script/parameters/app-chain/`.

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
