# Settlement Chain Upgrades <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [1. Overview](#1-overview)
- [2. Environment Defaults](#2-environment-defaults)
- [3. Choose Your Workflow](#3-choose-your-workflow)

## 1. Overview

There are two possible workflows for settlement chain upgrades. The parameter registry admin address can be controlled:

1. by a local private key, or
2. by Fireblocks.

The goals for testnets are minimal friction, whilst still proving out the Fireblocks approval process before mainnet.

## 2. Environment Defaults

| Environment       | Default      | To Override                     |
| ----------------- | ------------ | ------------------------------- |
| `testnet-dev`     | `WALLET`     | `ADMIN_ADDRESS_TYPE=FIREBLOCKS` |
| `testnet-staging` | `WALLET`     | `ADMIN_ADDRESS_TYPE=FIREBLOCKS` |
| `testnet`         | `FIREBLOCKS` | `ADMIN_ADDRESS_TYPE=WALLET`     |
| `mainnet`         | `FIREBLOCKS` | No override possible            |

Add the override variable to your command when you need to use the non-default signing method.

## 3. Choose Your Workflow

- **[README-wallet.md](README-wallet.md)** - Private key signing (simpler upgrade process)
- **[README-fireblocks.md](README-fireblocks.md)** - Fireblocks signing (multi-step upgrade process)
