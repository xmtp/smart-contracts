# Settlement Chain Smart Contracts

This document provides an overview of the smart contracts that operate on the `settlement chain`. It describes the purpose of each contract and how they interact with one another to form a cohesive system for managing nodes, fees, and cross-chain communication.

## Table of Contents

- [System Architecture Overview](#system-architecture-overview)
- [Contracts](#contracts)
  - [SettlementChainParameterRegistry.sol](#settlementchainparameterregistrysol)
  - [FeeToken.sol](#feetokensol)
  - [NodeRegistry.sol](#noderegistrysol)
  - [PayerRegistry.sol](#payerregistrysol)
  - [PayerReportManager.sol](#payerreportmanagersol)
  - [DistributionManager.sol](#distributionmanagersol)
  - [RateRegistry.sol](#rateregistrysol)
  - [SettlementChainGateway.sol](#settlementchaingatewaysol)
  - [DepositSplitter.sol](#depositsplittersol)
- [Upgrades and Migrations](#upgrades-and-migrations)

## System architecture overview

The `settlement chain` contracts are designed to manage a decentralized network of nodes and payers, and to facilitate the settlement of fees between them. The core functionality revolves around registering nodes, submitting and settling fees for off-chain network usage by payers, and distributing the collected revenue to the node operators and the protocol.

Here is a high-level flow of interactions:

- The `SettlementChainParameterRegistry` acts as a central source of truth for all configurable parameters, which are read by the other contracts.
  - The parameters are controlled by an account, which may be a single admin, a multi-sig, or eventually a DAO.
- The `FeeToken` is an `ERC20`-compliant token that serves as the primary medium of exchange for fees within the protocol, and wraps an established stablecoin 1:1.
  - All operations on the `settlement chain` have functions that can be used with `FeeToken` or the underlying `stablecoin`, for convenience.
- Nodes that operate the network are registered in the `NodeRegistry` as `NFTs`, which record their ownership and cryptographic keys.
- Payers, who are typically app and agent developers, deposit `FeeToken` (or the underlying `stablecoin`) into:
  - the `PayerRegistry` to fund their usage of the network, and
  - the `SettlementChainGateway` to fund their gas costs on an `app chain`.
  - Alternatively, payers can use the `DepositSplitter` to deposit `FeeToken` into the `PayerRegistry` and the `SettlementChainGateway` in a single transaction.
- The nodes collectively track network usage and submit fees owed by payers.
  - They use historically tracked rates from the `RateRegistry`.
  - They generate frequent and periodic `PayerReports` containing `Merkle` roots of the fees owed by payers.
  - These reports are signed by a `supermajority` of canonical nodes (50% + 1) and submitted to the `PayerReportManager`, which verifies the submitted reports.
- Anyone (most likely a node) can use the `PayerReportManager` `settle` function with a `Merkle` proof to process the fees for sequential subsets of payers.
  - This action calls the `PayerRegistry` to deduct the fees from the respective payers' balances.
  - Sequential subsets of payers are settled asynchronously until a `PayerReport` is fully settled.
- As an excess of unencumbered `FeeToken` builds up in the `PayerRegistry` (i.e. `FeeToken` no longer attributable to any payers' balances), anyone can trigger the excess to be sent to the `DistributionManager`.
- Node operators can then claim their share of the revenue from individual fully-settled `PayerReports`, via the `DistributionManager`.
  - They can then withdraw their accumulated claimed fees asynchronously, which is distributed to them in either `FeeToken` or the underlying `stablecoin`.
  - A portion of the fees are set aside for the `DistributionManager`'s `protocolFeesRecipient`, which can be a treasury, charity, or other recipient.
- Aside from aiding with bridging `FeeToken` to external `app chains`, the `SettlementChainGateway` facilitates sending configuration parameters from the `SettlementChainParameterRegistry` to parameter registry contracts on external `app chains`.

## Contracts

### `SettlementChainParameterRegistry.sol`

Serves as a centralized key-value store for configuration parameters used by all other contracts on the ``settlement chain. It inherits from a base `ParameterRegistry` and defines the keys for its own admin and migrator parameters. This allows for governance and upgrades to be managed predictably. Effectively, all contracts defer to this contract as the "book of truth" for all parameters, allowing anyone to poke any contract, at any time, to have it update its parameters from this administered registry, which removes the need for almost all access control logic in any other contract.

**Interactions**:

- **Read by**: Nearly all other `settlement chain` contracts (`DistributionManager`, `FeeToken`, `NodeRegistry`, `PayerRegistry`, `PayerReportManager`, `RateRegistry`, `SettlementChainGateway`, and `Factory`) to fetch their respective configuration parameters, such as admin addresses, fee rates, or external contract addresses.

### `FeeToken.sol`

An `ERC20`-compliant token that serves as the primary medium of exchange for fees within the protocol. It is a "wrapped" token, meaning it is backed 1:1 by an underlying `stablecoin` (like USDC). Users can `deposit` the underlying token to mint `FeeToken` and `withdraw` `FeeToken` to receive the underlying token back. The `FeeToken` is the gas token on an app chain, and exists to decouple the 3rd party underlying `stablecoin` from an `app chain`'s native gas token. The `FeeToken` has 6 decimals, which matches the decimals of the planned underlying `stablecoin` (USDC). The USDC is held by the `FeeToken` contract itself, and not transferred to, or held by, any other contract in the protocol.

**Interactions**:

- **Used by `PayerRegistry`**: Payers, who are typically app and agent developers, deposit `FeeToken` into the `PayerRegistry` to pay for network services. Withdrawals from the `PayerRegistry` are also in `FeeToken`.
- **Used by `DistributionManager`**: Fees collected from payers are distributed to node operators in the form of `FeeToken`.
- **Used by `SettlementChainGateway`**: This gateway uses `FeeToken` to facilitate paying for gas on connected XMTP `app chains`.

### `NodeRegistry.sol`

Manages the identities of the nodes that operate the network. Each node is represented as an `ERC721` NFT (non-enumerable variant), which proves ownership. The registry stores critical information for each node, such as its signing key and network address. It also maintains a distinction between "canonical" nodes, which are the core, trusted operators, and non-canonical ones. A separate `NodeRegistry` admin, defined by the `SettlementChainParameterRegistry`, can add or removed a node from the `canonical` set.

**Interactions**:

- **Queried by `PayerReportManager`**: To verify that the signatures on a `PayerReport` were created by valid, canonical nodes.
- **Queried by `DistributionManager`**: To verify the ownership of a node when its operator attempts to claim their earned fees.
- **Reads from `SettlementChainParameterRegistry`**: To get its administrative address and other configuration.

### `PayerRegistry.sol`

Manages the accounts and balances of the network's payers. Payers deposit `FeeToken` (or the underlying `stablecoin`) here to cover their usage fees. The contract handles these deposits, processes withdrawals (which are subject to a time lock), and deducts fees from payer balances as they are settled.

**Interactions**:

- **Receives calls from `PayerReportManager`**: The `settleUsage` function is called by the `PayerReportManager` to debit payers' allocated funds based on the verified usage reports.
- **Sends fees to `DistributionManager`**: It transfers the collected fees to the `DistributionManager` to be distributed among stakeholders.
- **Holds `FeeToken`**: It holds the `FeeToken` deposited by payers.
- **Reads from `SettlementChainParameterRegistry`**: To get addresses for the `settler` and `feeDistributor`, as well as parameters like `minimumDeposit`.

### `PayerReportManager.sol`

The entry point for fee settlement. Nodes submit signed `PayerReports` to this contract. Each report contains a `Merkle` root summarizing the fees owed by many different payers for a given period. The contract's primary job is to verify the authenticity of these reports by checking the signatures of the reporting nodes. Each `PayerReport` is defined for a specific "originating node", and defines usage fees between a specific `startSequenceId` and `endSequenceId`, with no 2 `PayerReports` for the same originating node having overlapping `startSequenceId` and `endSequenceId` ranges.

**Interactions**:

- **Interacts with `NodeRegistry`**: To fetch the list of canonical nodes and their signing keys for signature verification.
- **Calls `PayerRegistry`**: Its `settle` function calls `PayerRegistry.settleUsage()` to execute the fee deductions from payer balances.
- **Reads from `SettlementChainParameterRegistry`**: To get the `protocolFeeRate`.

### `DistributionManager.sol`

Responsible for the final step in the economic loop: distributing the collected fees. It allows verified node operators to claim their portion of the fees earned from network operations. A `PayerReport`'s settle fees are distributed equally to all active node operators defined in the `PayerReport`, with a portion of the total being set aside for the `DistributionManager`'s `protocolFeesRecipient`, as defined by the `protocolFeeRate` at the time the `PayerReport` was submitted.

**Interactions**:

- **Interacts with `PayerReportManager`**: To get the details of settled payer reports, which are necessary to calculate the fee distribution.
- **Interacts with `NodeRegistry`**: To verify that the address claiming fees is the legitimate owner of the node.
- **Receives fees from `PayerRegistry`**: The `PayerRegistry` sends its accumulated fees here for distribution.
- **Holds and distributes `FeeToken`**.

### `RateRegistry.sol`

Maintains a historical (timestamped) record of the various fee rates for the protocol, such as fees for messages, storage, and congestion. This allows for dynamic pricing based on network conditions. Anyone can poke the `RateRegistry` to update it's rate parameters from the `SettlementChainParameterRegistry`.

**Interactions**:

- **Read by off-chain nodes**: While not directly read by other onchain contracts in this directory, the rates stored here are critical for the off-chain nodes that calculate the fees included in `PayerReports`.
- **Reads from `SettlementChainParameterRegistry`**: To update its own rate parameters.

### `SettlementChainGateway.sol`

Serves as a bridge from the `settlement chain` (acting as an L2) to connected Arbitrum L3 “Orbit” XMTP `app chains`. The requirement for Arbitrum L3s exists because the bulk of the messaging network data would be too costly even for an L2, so a reasonably secure chain with high throughput is needed. These `app chains` can be isolated and do not need access or composability with 3rd-party smart contracts (like DeFi or ENS). The gateway relies on Arbitrum-specific architecture and communicates through the `IERC20InboxLike` interface, the standard mechanism for bridging from an L2 to its L3s. The gateway's main functions are to synchronize configuration parameters and to bridge `FeeToken` to these `app chains` to be used for gas payments.

**Interactions**:

- **Reads from `SettlementChainParameterRegistry`**: To fetch the parameters that need to be sent to the `app chains`.
- **Interacts with `IAppChainGatewayLike`**: This is the interface for the corresponding gateway contract on the destination `app chain`.
- **Interacts with `IERC20InboxLike`**: This is an interface for the Arbitrum-specific bridging contract that facilitates messaging and asset transfers from the `settlement chain` (L2) to an `app chain` (L3).
- **Uses `FeeToken`**: For deposits and for funding transactions on `app chains`.

### `DepositSplitter.sol`

A periphery convenience contract that is responsible for splitting deposits between the `PayerRegistry` and the `SettlementChainGateway`. It allows payers to deposit `FeeToken` (or the underlying `stablecoin`) into the `PayerRegistry` and the `SettlementChainGateway` in a single transaction.

**Interactions**:

- **Interacts with `PayerRegistry`**: To deposit `FeeToken` into the `PayerRegistry`.
- **Interacts with `SettlementChainGateway`**: To deposit `FeeToken` into the `SettlementChainGateway`.

## Upgrades and Migrations

All contracts use a `Migratable` pattern. This means that they have a `migrate` function that can be called by anyone to update the contract's implementation and/or storage, so long as a trusted `Migrator` contract has been set for that contract in the `SettlementChainParameterRegistry` by the registry admin/governance. Upon a `migrate()` call, the contract fetches the `Migrator` address defined for it, from the `SettlementChainParameterRegistry`, and delegate calls it's fallback function, with no arguments, giving that `Migrator` contract complete control over the contract's storage, which includes the pointer to the contract's implementation.
