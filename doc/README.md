# XMTP Network Smart Contracts — Documentation Hub <!-- omit from toc -->

Central index for all protocol documentation, operator runbooks, and in-code references.

## Table of Contents <!-- omit from toc -->

- [Protocol documentation](#protocol-documentation)
  - [Core system understanding](#core-system-understanding)
  - [Actor-specific guides](#actor-specific-guides)
  - [Implementation details](#implementation-details)
- [Operator runbooks](#operator-runbooks)
  - [Contract upgrades](#contract-upgrades)
  - [Single-contract deployments](#single-contract-deployments)
  - [Parameter management](#parameter-management)
  - [Node registry administration](#node-registry-administration)
- [In-code documentation](#in-code-documentation)
- [Quick navigation](#quick-navigation)

## Protocol documentation

Narrative docs that explain **what** the system is and **why** it works the way it does. Start here if you are new.

### Core system understanding

| Document                                          | Description                                                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| **[System architecture](./architecture.md)**      | _Start here._ Dual-chain design, actors, economic model, cross-chain communication, and security model. |
| **[Contracts](./contracts.md)**                   | All smart contracts: purpose, key components, deployment order, data flow, and design rationale.        |
| **[Parameter registry](./parameter-registry.md)** | Every `xmtp.*` parameter key, cross-chain bridging flow (PlantUML + Mermaid), and type reference.       |

### Actor-specific guides

| Document                                  | Description                                                                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **[Payers](./payers.md)**                 | How service providers fund the network: manual deposits, DepositSplitter, and Funding Portal.                                  |
| **[Node operators](./node-operators.md)** | Node identification (NFT ID scheme), canonical network, onboarding, synchronization, and authentication.                       |
| **[Payer reports](./payer-reports.md)**   | Economic settlement end-to-end: report structure, EIP-712 signing, Merkle proofs, settlement, node payouts, and protocol fees. |

### Implementation details

| Document                              | Description                                                                                                              |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **[Deployment](./deployment.md)**     | Greenfield environment rollout via `./dev/*` shell helpers; links to Foundry runbooks for day-two operations.            |
| **[Dependencies](./dependencies.md)** | Contract communication dependency diagram (Mermaid) and call-level breakdown per contract.                               |
| **[Proxies](./proxies.md)**           | Proxy, Factory, and Migration patterns — deterministic deploys, atomic initialization, and governance-friendly upgrades. |

## Operator runbooks

Step-by-step procedural guides live under [`doc/runbooks/`](./runbooks/README.md). Each area has a top-level `README.md` and, where applicable, per-workflow variants for **wallet** (private key) and **Fireblocks** signing. The Foundry scripts they drive remain under [`script/`](../script/).

### Contract upgrades

Upgrade an existing proxy to a new implementation (same proxy address, new code).

| Chain      | Entry point                                                                                      | Wallet                                                      | Fireblocks                                                          |
| ---------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------- |
| Settlement | [`runbooks/upgrades/settlement-chain/README.md`](./runbooks/upgrades/settlement-chain/README.md) | [wallet.md](./runbooks/upgrades/settlement-chain/wallet.md) | [fireblocks.md](./runbooks/upgrades/settlement-chain/fireblocks.md) |
| App chain  | [`runbooks/upgrades/app-chain/README.md`](./runbooks/upgrades/app-chain/README.md)               | [wallet.md](./runbooks/upgrades/app-chain/wallet.md)        | [fireblocks.md](./runbooks/upgrades/app-chain/fireblocks.md)        |

For upgrades that also migrate storage, see the [Custom migration guide](./runbooks/upgrades/custom-migration-guide.md).

### Single-contract deployments

Deploy a **new proxy + implementation pair** for an individual contract (new address).

| Guide                                                                                                                | Description                                                                                   |
| -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [`runbooks/single-deployments/any-chain/README.md`](./runbooks/single-deployments/any-chain/README.md)               | Any-chain overview and prerequisites.                                                         |
| [deploy-factory.md](./runbooks/single-deployments/any-chain/deploy-factory.md)                                       | `Factory` deployment via CREATE2.                                                             |
| [`runbooks/single-deployments/settlement-chain/README.md`](./runbooks/single-deployments/settlement-chain/README.md) | Settlement-chain overview, three-step process, environment prerequisites.                     |
| [deploy-node-registry.md](./runbooks/single-deployments/settlement-chain/deploy-node-registry.md)                    | **System invariant — requires human intervention.** See the doc for breaking-change criteria. |
| [deploy-payer-report-manager.md](./runbooks/single-deployments/settlement-chain/deploy-payer-report-manager.md)      | PayerReportManager deployment and dependency updates.                                         |
| [deploy-distribution-manager.md](./runbooks/single-deployments/settlement-chain/deploy-distribution-manager.md)      | DistributionManager deployment and dependency updates.                                        |
| [deploy-deposit-splitter.md](./runbooks/single-deployments/settlement-chain/deploy-deposit-splitter.md)              | DepositSplitter redeployment across testnet environments (non-upgradeable).                   |

### Parameter management

Set, read, and bridge `xmtp.*` parameters across chains.

| Chain                | Entry point                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| Settlement           | [`runbooks/parameters/settlement-chain/README.md`](./runbooks/parameters/settlement-chain/README.md) |
| App chain (bridging) | [`runbooks/parameters/app-chain/README.md`](./runbooks/parameters/app-chain/README.md)               |

### Node registry administration

Admin operations on the NodeRegistry contract (add nodes, manage canonical network, set base URI).

| Guide                                                                                      | Description                      |
| ------------------------------------------------------------------------------------------ | -------------------------------- |
| [`runbooks/admin/settlement-chain/README.md`](./runbooks/admin/settlement-chain/README.md) | Overview and workflow selection. |
| [wallet.md](./runbooks/admin/settlement-chain/wallet.md)                                   | Wallet signing commands.         |
| [fireblocks.md](./runbooks/admin/settlement-chain/fireblocks.md)                           | Fireblocks signing commands.     |

## In-code documentation

| Location                                                              | Description                                                                             |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| [`src/settlement-chain/README.md`](../src/settlement-chain/README.md) | Settlement chain contracts overview, interaction flow, and upgrade/migration mechanics. |
| [`CLAUDE.md`](../CLAUDE.md)                                           | AI assistant guidance: build/test commands and code style guidelines.                   |

## Quick navigation

| I want to...                          | Go to                                                         |
| ------------------------------------- | ------------------------------------------------------------- |
| Understand the system                 | [System architecture](./architecture.md)                      |
| Integrate as a service provider       | [Payers](./payers.md)                                         |
| Run network infrastructure            | [Node operators](./node-operators.md)                         |
| Understand the economics              | [Payer reports](./payer-reports.md)                           |
| Deploy a new environment from scratch | [Deployment](./deployment.md)                                 |
| Upgrade a live contract               | [Contract upgrades](#contract-upgrades)                       |
| Deploy a single new contract          | [Single-contract deployments](#single-contract-deployments)   |
| Change a parameter                    | [Parameter management](#parameter-management)                 |
| Add or manage nodes                   | [Node registry administration](#node-registry-administration) |
