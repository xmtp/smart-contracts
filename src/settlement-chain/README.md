# Settlement chain smart contracts

This document provides an overview of the smart contracts that operate on the settlement chain. It describes the purpose of each contract and how they interact with one another to form a cohesive system for managing nodes, fees, and cross-chain communication.

## System architecture overview

The settlement chain contracts are designed to manage a decentralized network of nodes. The core functionality revolves around registering nodes, tracking network usage by payers, calculating fees, settling those fees, and distributing the collected revenue to the node operators and the protocol.

Here is a high-level flow of interactions:

1.  The `SettlementChainParameterRegistry` acts as a central source of truth for all configurable parameters, which are read by the other contracts.
2.  Nodes that operate the network are registered in the `NodeRegistry` as `NFTs`, which record their ownership and cryptographic keys.
3.  Payers, who are typically app and agent developers, deposit `FeeToken` (a wrapped `stablecoin`) into the `PayerRegistry` to fund their usage of the network.
4.  The nodes collectively track network usage. They generate `PayerReports` containing `Merkle` roots of the fees owed by payers. These reports are signed by a `supermajority` of canonical nodes and submitted to the `PayerReportManager`.
5.  The `PayerReportManager` verifies the submitted reports. Its `settle` function can then be called with a `Merkle` proof to process the fees for a subset of payers. This action calls the `PayerRegistry` to deduct the fees from the respective payers' balances.
6.  The `PayerRegistry` sends the collected fees to the `DistributionManager`.
7.  Node operators can then claim their share of the revenue from the `DistributionManager`.
8.  The `SettlementChainGateway` facilitates sending configuration parameters and bridging assets to external `appchains`.

## Contracts

### `SettlementChainParameterRegistry.sol`

This contract serves as a centralized key-value store for configuration parameters used by all other contracts on the settlement chain. It inherits from a base `ParameterRegistry` and defines the keys for its own admin and migrator parameters. This allows for governance and upgrades to be managed in a predictable way.

**Interactions**:

- **Read by**: Nearly all other settlement chain contracts (`DistributionManager`, `FeeToken`, `NodeRegistry`, `PayerRegistry`, `PayerReportManager`, `RateRegistry`, `SettlementChainGateway`) to fetch their respective configuration parameters, such as admin addresses, fee rates, or external contract addresses.

### `FeeToken.sol`

An ERC20-compliant token that serves as the primary medium of exchange for fees within the protocol. It is a "wrapped" token, meaning it is backed 1:1 by an underlying `stablecoin` (like USDC). Users can `deposit` the underlying token to mint `FeeToken` and `withdraw` `FeeToken` to receive the underlying token back.

**Interactions**:

- **Used by `PayerRegistry`**: Payers, who are typically app and agent developers, deposit `FeeToken` into the `PayerRegistry` to pay for network services. Withdrawals from the `PayerRegistry` are also in `FeeToken`.
- **Used by `DistributionManager`**: Fees collected from payers are distributed to node operators in the form of `FeeToken`.
- **Used by `SettlementChainGateway`**: This gateway uses `FeeToken` to facilitate paying for gas on connected app chains, including the XMTP Appchain.

### `NodeRegistry.sol`

This contract manages the identities of the nodes that operate the network. Each node is represented as an ERC721 NFT, which proves ownership. The registry stores critical information for each node, such as its signing key and network address. It also maintains a distinction between "canonical" nodes, which are the core, trusted operators, and non-canonical ones.

**Interactions**:
- **Queried by `PayerReportManager`**: To verify that the signatures on a `PayerReport` were created by valid, canonical nodes.
- **Queried by `DistributionManager`**: To verify the ownership of a node when its operator attempts to claim their earned fees.
- **Reads from `SettlementChainParameterRegistry`**: To get its administrative address and other configuration.

### `PayerRegistry.sol`

This contract manages the accounts and balances of the network's payers. Payers deposit `FeeToken` here to cover their usage fees. The contract handles these deposits, processes withdrawals (which are subject to a time lock), and deducts fees from payer balances as they are settled.

**Interactions**:

- **Receives calls from `PayerReportManager`**: The `settleUsage` function is called by the `PayerReportManager` to debit payers' allocated funds based on the verified usage reports.
- **Sends fees to `DistributionManager`**: It transfers the collected fees to the `DistributionManager` to be distributed among stakeholders.
- **Holds `FeeToken`**: It holds the `FeeToken` deposited by payers.
- **Reads from `SettlementChainParameterRegistry`**: To get addresses for the `settler` and `feeDistributor`, as well as parameters like `minimumDeposit`.

### `PayerReportManager.sol`

This contract is the entry point for fee settlement. Nodes submit signed `PayerReports` to this contract. Each report contains a `Merkle` root summarizing the fees owed by many different payers for a given period. The contract's primary job is to verify the authenticity of these reports by checking the signatures of the reporting nodes.

**Interactions**:

- **Interacts with `NodeRegistry`**: To fetch the list of canonical nodes and their signing keys for signature verification.
- **Calls `PayerRegistry`**: Its `settle` function calls `PayerRegistry.settleUsage()` to execute the fee deductions from payer balances.
- **Reads from `SettlementChainParameterRegistry`**: To get the `protocolFeeRate`.

### `DistributionManager.sol`

This contract is responsible for the final step in the economic loop: distributing the collected fees. It allows verified node operators to claim their portion of the fees earned from network operations.

**Interactions**:

- **Interacts with `PayerReportManager`**: To get the details of settled payer reports, which are necessary to calculate the fee distribution.
- **Interacts with `NodeRegistry`**: To verify that the address claiming fees is the legitimate owner of the node.
- **Receives fees from `PayerRegistry`**: The `PayerRegistry` sends its accumulated fees here for distribution.
- **Holds and distributes `FeeToken`**.

### `RateRegistry.sol`

This contract maintains a historical record of the various fee rates for the protocol, such as fees for messages, storage, and congestion. This allows for dynamic pricing based on network conditions.

**Interactions**:

- **Read by offchain nodes**: While not directly read by other onchain contracts in this directory, the rates stored here are critical for the offchain nodes that calculate the fees included in `PayerReports`.
- **Reads from `SettlementChainParameterRegistry`**: To update its own rate parameters.

### `SettlementChainGateway.sol`

This contract serves as a bridge from the settlement chain (acting as an L2) to other connected `blockchains`, which must be Arbitrum L3s (also known as "Orbit chains"). This is a specific requirement because the gateway is tightly coupled with Arbitrum's architecture, using an `IERC20InboxLike` interface to communicate. This interface is the standard for bridging from an Arbitrum L2 to its L3s. The gateway's main functions are to synchronize configuration parameters and to bridge `FeeToken` to these `appchains` to be used for gas payments.

**Interactions**:

- **Reads from `SettlementChainParameterRegistry`**: To fetch the parameters that need to be sent to the `appchains`.
- **Interacts with `IAppChainGatewayLike`**: This is the interface for the corresponding gateway contract on the destination `appchain`.
- **Interacts with `IERC20InboxLike`**: This is an interface for the Arbitrum-specific bridging contract that facilitates messaging and asset transfers from the settlement chain (L2) to an `appchain` (L3).
- **Uses `FeeToken`**: For deposits and for funding transactions on `appchains`.
