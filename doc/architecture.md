# XMTP network system architecture

> Last edited: 09/15/2025

- [XMTP network system architecture](#xmtp-network-system-architecture)
  - [System overview](#system-overview)
  - [Messaging protocol](#messaging-protocol)
  - [Chain architecture](#chain-architecture)
    - [Settlement chain (Base L2)](#settlement-chain-base-l2)
    - [App chain (XMTP L3)](#app-chain-xmtp-l3)
    - [Design rationale](#design-rationale)
  - [Actors](#actors)
    - [End users](#end-users)
    - [Payers](#payers)
      - [Setup requirements](#setup-requirements)
      - [Message publishing](#message-publishing)
    - [Node operators](#node-operators)
      - [xmtpd service components](#xmtpd-service-components)
      - [Onboarding process](#onboarding-process)
    - [Administrators](#administrators)
      - [Responsibilities](#responsibilities)
  - [Economic model](#economic-model)
    - [Fee structure](#fee-structure)
    - [Settlement process](#settlement-process)
    - [Token economics](#token-economics)
  - [Cross-chain communication](#cross-chain-communication)
    - [Parameter flow](#parameter-flow)
    - [Reliability features](#reliability-features)
  - [Security model](#security-model)
    - [Trust assumptions](#trust-assumptions)
    - [Consensus mechanism](#consensus-mechanism)
    - [Upgrade security](#upgrade-security)

## System overview

XMTP is a decentralized messaging protocol that enables secure, scalable communication through a multi-chain architecture. The system combines the security and economic finality of Layer 2 chains with the high throughput and low cost of Layer 3 chains to create an efficient messaging infrastructure.

```mermaid
graph TB
    subgraph "End Users"
        EU[Mobile/Web Apps]
    end

    subgraph "Application Layer"
        P[Payers/Gateway Services]
    end

    subgraph "XMTP L3 App Chain"
        GMB[GroupMessageBroadcaster]
        IUB[IdentityUpdateBroadcaster]
        ACPR[AppChainParameterRegistry]
        ACG[AppChainGateway]
    end

    subgraph "XMTP Node Network"
        N1[Node 1]
        N2[Node 2]
        N3[Node N...]
    end

    subgraph "Base L2 Settlement Chain"
        NR[NodeRegistry]
        PR[PayerRegistry]
        RR[RateRegistry]
        SCPR[SettlementChainParameterRegistry]
        SCG[SettlementChainGateway]
        DM[DistributionManager]
        PRM[PayerReportManager]
        FT[FeeToken]
        DS[DepositSplitter]
    end

    subgraph "External"
        USDC[USDC Token]
        GOV[Governance/Admin]
    end

    EU --> P
    P --> GMB
    P --> IUB
    P --> N1
    P --> PR

    N1 <--> N2
    N2 <--> N3
    N1 <--> N3

    N1 --> PRM
    N2 --> PRM
    N3 --> PRM

    PRM --> PR
    PR --> DM
    DM --> N1
    DM --> N2
    DM --> N3

    SCG <--> ACG
    SCPR --> SCG
    SCG --> ACPR
    ACPR --> GMB
    ACPR --> IUB

    GOV --> SCPR
    GOV --> NR

    P --> DS
    DS --> PR
    DS --> SCG
    USDC --> FT
    FT --> DS

    style EU fill:#e1f5fe
    style P fill:#f3e5f5
    style N1 fill:#e8f5e8
    style N2 fill:#e8f5e8
    style N3 fill:#e8f5e8
    style GMB fill:#fff3e0
    style IUB fill:#fff3e0
```

## Messaging protocol

The XMTP Broadcast Network enables secure messaging through the [Messaging Layer Security](https://messaginglayersecurity.rocks/) (MLS) standard, providing end-to-end encryption and forward secrecy for chat apps and agents.

The MLS standard defines five types of messages, with two types stored onchain through [broadcaster contracts](../src/abstract/PayloadBroadcaster.sol):

- **Group messages**: Stored via GroupMessageBroadcaster for forced inclusion and censorship resistance
- **Identity updates**: Stored via IdentityUpdateBroadcaster for identity management and key rotation

The remaining message types are published directly to xmtpd nodes for offchain processing and delivery.

## Chain architecture

The XMTP network employs a dual-chain architecture optimized for both economic security and messaging throughput. For detailed contract information, see the [system contracts document](./contracts.md).

### Settlement chain (Base L2)

The XMTP Settlement Chain handles economic operations, governance, and system parameters:

- **Economic functions**: Fee collection, node operator payments, payer account management
- **Governance**: System parameter management, node registry, upgrade coordination
- **Cross-chain coordination**: Parameter bridging to XMTP App Chains via retryable tickets
- **Key contracts**: NodeRegistry, PayerRegistry, RateRegistry, DistributionManager, and FeeToken

### App chain (XMTP L3)

The XMTP App Chain focuses on high-throughput message broadcasting:

- **Message storage**: Onchain storage for group messages and identity updates
- **Low-cost operations**: Optimized for high-frequency messaging operations
- **Parameter consumption**: Receives configuration from XMTP Settlement Chain
- **Key contracts**: GroupMessageBroadcaster, `IdentityUpdateBroadcaster, and AppChainParameterRegistry

### Design rationale

- **Cost optimization**: Expensive economic operations on L2, cheap messaging on L3
- **Scalability**: L3 chains can be horizontally scaled as needed
- **Security**: Economic finality secured by L2, messaging availability on L3

## Actors

### End users

End users are the ultimate consumers of XMTP messaging services, typically accessing the network through mobile apps, web interfaces, or other client applications. They send and receive MLS-encrypted messages without directly interacting with the blockchain infrastructure.

### Payers

Payers are service providers (typically companies with chat apps) who fund network operations to serve their end users. They operate gateway services and maintain funded accounts to pay for messaging costs.

#### Setup requirements

- Deploy a [gateway service](https://github.com/xmtp/xmtpd/tree/main/pkg/api/payer) with their private key
- Fund accounts in PayerRegistry for offchain message costs
- Maintain xUSD balances on XMTP App Chains for onchain message costs

#### Message publishing

- **Onchain messages**: Published directly to broadcaster contracts (GroupMessageBroadcaster and IdentityUpdateBroadcaster)
- **Offchain messages**: Published through xmtpd nodes, costs settled through PayerReports

### Node operators

Node operators maintain the XMTP Broadcast Network infrastructure by running [xmtpd](https://github.com/xmtp/xmtpd) services that process messages, maintain network consensus, and earn fees for their services.

#### xmtpd service components

- **Message APIs**: Interfaces for payers to publish and retrieve MLS messages
- **Node registry**: Maintains connections with other canonical network nodes
- **Cross-chain indexer**: Monitors events on both XMTP Settlement and XMTP App Chains

#### Onboarding process

1. **NFT minting**: Protocol administrator mints a NodeRegistry NFT
2. **Canonical network addition**: Administrator enables the node for the canonical network
3. **Service configuration**: Node operator configures xmtpd with their private key
4. **Network synchronization**: Node connects to and synchronizes with other canonical nodes

### Administrators

Administrators manage system governance, parameters, and network operations through multi-signature wallets and eventual governance mechanisms.

#### Responsibilities

- **Parameter management**: Update system parameters via SettlementChainParameterRegistry
- **Node management**: Add/remove nodes from the canonical XMTP Broadcast Network
- **Upgrade coordination**: Manage contract upgrades and migrations
- **Economic policy**: Set fee rates, distribution parameters, and protocol policies

## Economic model

The XMTP network operates on a fee-based economic model where payers fund operations and node operators earn rewards for providing services.

### Fee structure

- **Onchain messages**: Direct gas costs paid upfront by payers on the XMTP App Chain
- **Offchain messages**: Usage-based fees settled periodically through PayerReports
- **Protocol fees**: Percentage of total fees reserved for protocol treasury

### Settlement process

```mermaid
sequenceDiagram
    participant P as Payers
    participant N as Node Operators
    participant PRM as PayerReportManager
    participant PR as PayerRegistry
    participant DM as DistributionManager

    Note over N: Nodes track usage by payers
    N->>PRM: Submit PayerReport (every 12 hours)
    PRM->>PRM: Verify signatures & merkle proofs
    PRM->>PR: Deduct fees from payer balances
    PR->>DM: Transfer fees for distribution
    DM->>N: Distribute fees to node operators
    DM->>DM: Reserve protocol fees
```

### Token economics

- **FeeToken (xUSD)**: ERC20 token backed 1:1 by USDC for network fees
- **Deposit mechanisms**: Direct deposits or DepositSplitter for cross-chain funding
- **Withdrawal locks**: Time-delayed withdrawals for security

## Cross-chain communication

Parameter synchronization between XMTP Settlement and App Chains uses Arbitrum's retryable ticket mechanism.

### Parameter flow

```mermaid
sequenceDiagram
    participant Admin as Administrator
    participant SCPR as SettlementChainParameterRegistry
    participant SCG as SettlementChainGateway
    participant ACG as AppChainGateway
    participant ACPR as AppChainParameterRegistry

    Admin->>SCPR: Update parameter
    Note over SCG: User initiates parameter bridge
    SCG->>SCPR: Fetch current parameters
    SCG->>ACG: Send retryable ticket
    ACG->>ACPR: Update parameters
    Note over ACPR: Parameters available for app chain contracts
```

### Reliability features

- **Guaranteed delivery**: Retryable tickets ensure parameter updates reach XMTP App Chains
- **Nonce tracking**: Prevents out-of-order parameter updates
- **Failure recovery**: Failed tickets can be retried

## Security model

### Trust assumptions

- **Node operators**: Trusted to process messages honestly and submit accurate reports
- **Administrators**: Multi-sig controlled parameter updates and governance
- **Cross-chain security**: Relies on Arbitrum's L2→L3 security guarantees

### Consensus mechanism

- **Canonical network**: Subset of registered nodes designated as canonical
- **Message consistency**: Nodes subscribe to each other for consistent message views
- **Report validation**: Multiple nodes must agree on PayerReports before settlement

### Upgrade security

- **Migratable pattern**: External migratable contracts enable secure upgrades
- **Access control**: Admin-controlled upgrade authorization
