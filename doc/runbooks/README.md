# Operator Runbooks

Step-by-step procedural guides for day-two operations on the XMTP contracts. The Foundry scripts these runbooks drive live under [`script/`](../../script/); the narrative protocol docs live one level up in [`doc/`](../README.md).

Each area has a top-level `README.md`. Where a workflow supports multiple signing paths, it has `wallet.md` (private key) and `fireblocks.md` (Fireblocks-managed signer) variants.

## Contract upgrades

Upgrade an existing proxy to a new implementation — same proxy address, new code.

| Chain      | Entry point                                                                    | Wallet                                             | Fireblocks                                                 |
| ---------- | ------------------------------------------------------------------------------ | -------------------------------------------------- | ---------------------------------------------------------- |
| Settlement | [`upgrades/settlement-chain/README.md`](./upgrades/settlement-chain/README.md) | [wallet.md](./upgrades/settlement-chain/wallet.md) | [fireblocks.md](./upgrades/settlement-chain/fireblocks.md) |
| App chain  | [`upgrades/app-chain/README.md`](./upgrades/app-chain/README.md)               | [wallet.md](./upgrades/app-chain/wallet.md)        | [fireblocks.md](./upgrades/app-chain/fireblocks.md)        |

Upgrades that also migrate storage: [custom-migration-guide.md](./upgrades/custom-migration-guide.md).

## Single-contract deployments

Deploy a new proxy + implementation pair (new address) for an individual contract.

| Guide                                                                                                  | Description                                                                                   |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| [`single-deployments/any-chain/README.md`](./single-deployments/any-chain/README.md)                   | Any-chain overview and prerequisites.                                                         |
| [deploy-factory.md](./single-deployments/any-chain/deploy-factory.md)                                  | `Factory` deployment via CREATE2.                                                             |
| [`single-deployments/settlement-chain/README.md`](./single-deployments/settlement-chain/README.md)     | Settlement-chain overview and prerequisites.                                                  |
| [deploy-node-registry.md](./single-deployments/settlement-chain/deploy-node-registry.md)               | **System invariant — requires human intervention.** See the doc for breaking-change criteria. |
| [deploy-payer-report-manager.md](./single-deployments/settlement-chain/deploy-payer-report-manager.md) | PayerReportManager deployment and dependency updates.                                         |
| [deploy-distribution-manager.md](./single-deployments/settlement-chain/deploy-distribution-manager.md) | DistributionManager deployment and dependency updates.                                        |
| [deploy-deposit-splitter.md](./single-deployments/settlement-chain/deploy-deposit-splitter.md)         | DepositSplitter redeployment across testnet environments (non-upgradeable).                   |

## Parameter management

Set, read, and bridge `xmtp.*` parameters across chains.

| Chain                | Entry point                                                                        |
| -------------------- | ---------------------------------------------------------------------------------- |
| Settlement           | [`parameters/settlement-chain/README.md`](./parameters/settlement-chain/README.md) |
| App chain (bridging) | [`parameters/app-chain/README.md`](./parameters/app-chain/README.md)               |

## Node registry administration

Admin operations on the `NodeRegistry` contract — add nodes, manage canonical network, set base URI.

| Guide                                                                    | Description                      |
| ------------------------------------------------------------------------ | -------------------------------- |
| [`admin/settlement-chain/README.md`](./admin/settlement-chain/README.md) | Overview and workflow selection. |
| [wallet.md](./admin/settlement-chain/wallet.md)                          | Wallet signing commands.         |
| [fireblocks.md](./admin/settlement-chain/fireblocks.md)                  | Fireblocks signing commands.     |
