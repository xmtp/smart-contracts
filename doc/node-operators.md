# XMTP node operators

- [XMTP node operators](#xmtp-node-operators)
  - [Node identification system](#node-identification-system)
  - [Canonical network](#canonical-network)
  - [Node onboarding process](#node-onboarding-process)
  - [Canonical network management](#canonical-network-management)
  - [Node synchronization process](#node-synchronization-process)
  - [Key features](#key-features)
    - [Node authentication](#node-authentication)
    - [Network consensus](#network-consensus)
    - [Operational management](#operational-management)

Node operators are managed through the [Node Registry](../src/settlement-chain/NodeRegistry.sol) contract, where they are registered as NFTs representing their node ownership and operational rights.

The node operator configures the `xmtpd` service to use the wallet private key holding the NFT, authenticating the node during startup and network operations.

## Node identification system

The `NodeRegistry` mints NFTs starting at ID 100, increasing by 100 for each new NFT minted. This ID serves as the unique node identifier, and each message published to a specific node is identified with the tuple `[originator_id, sequence_id]`, where:

- `originator_id` is the NFT ID (100, 200, 300, etc.)
- `sequence_id` is a monotonically increasing counter

This system guarantees that any message published to the network is unique and easily traceable.

## Canonical network

While there are no limitations on the total number of node operators that can exist, only a maximum of approximately 20-25 nodes participate in the `canonical network` at any given time for performance reasons. This limit is enforced by the protocol administrator through the `maxCanonicalNodes` parameter in the `NodeRegistry`.

The protocol administrator can add or remove specific nodes from the canonical network using the `addToNetwork` and `removeFromNetwork` functions.

## Node onboarding process

The onboarding process involves minting a new node NFT and registering the node operator with the XMTP Broadcast Network:

```mermaid
sequenceDiagram
    participant Admin as Protocol Administrator
    participant NO as Node Operator
    participant NR as NodeRegistry
    participant Wallet as Node Operator Wallet

    Note over Admin, Wallet: Phase 1: Node Registration
    Admin->>NR: addNode(owner, signingPublicKey, httpAddress)
    activate NR
    NR->>NR: Generate nodeId (increment by 100)
    NR->>NR: Derive signer address from public key
    NR->>NR: Create Node struct (non-canonical initially)
    NR->>Wallet: Mint NFT with nodeId
    NR->>Admin: Return nodeId and signer address
    NR->>NR: Emit NodeAdded event
    deactivate NR

    Note over Admin, Wallet: Phase 2: Node Configuration
    NO->>NO: Configure xmtpd service with private key
    NO->>NO: Set up HTTP endpoint for node communication
    NO->>NR: Verify NFT ownership in wallet

    Note over Admin, Wallet: Phase 3: Service Startup
    NO->>NO: Start xmtpd service
    Note over NO: Node ready for canonical network addition
```

## Canonical network management

Administrators manage which nodes participate in the canonical network through dedicated functions:

```mermaid
sequenceDiagram
    participant Admin as Protocol Administrator
    participant NR as NodeRegistry
    participant Node as Node Operator

    Note over Admin, Node: Adding Node to Canonical Network
    Admin->>NR: addToNetwork(nodeId)
    activate NR
    NR->>NR: Check if node already canonical
    NR->>NR: Verify canonical node limit not exceeded
    NR->>NR: Set node.isCanonical = true
    NR->>NR: Increment canonicalNodesCount
    NR->>Admin: Emit NodeAddedToCanonicalNetwork event
    deactivate NR

    Note over Node: Node now participates in canonical network

    Note over Admin, Node: Removing Node from Canonical Network
    Admin->>NR: removeFromNetwork(nodeId)
    activate NR
    NR->>NR: Verify node exists and is canonical
    NR->>NR: Set node.isCanonical = false
    NR->>NR: Decrement canonicalNodesCount
    NR->>Admin: Emit NodeRemovedFromCanonicalNetwork event
    deactivate NR

    Note over Node: Node removed from canonical network
```

## Node synchronization process

When an `xmtpd` service starts up, it follows a systematic process to synchronize with the canonical network:

```mermaid
sequenceDiagram
    participant XMTPD as xmtpd Service
    participant NR as NodeRegistry
    participant CN1 as Canonical Node 1
    participant CN2 as Canonical Node 2
    participant CNn as Canonical Node N
    participant DB as Local Database

    Note over XMTPD, DB: Phase 1: Service Startup
    XMTPD->>XMTPD: Start xmtpd service
    XMTPD->>XMTPD: Load configuration and private key
    XMTPD->>NR: Verify node NFT ownership

    Note over XMTPD, DB: Phase 2: Canonical Network Discovery (Initial + Every N Minutes)
    XMTPD->>NR: Query all canonical nodes (startup)
    activate NR
    NR->>XMTPD: Return list of canonical nodes with HTTP addresses
    deactivate NR

    loop Every N Minutes
        XMTPD->>NR: Query canonical nodes (periodic refresh)
        activate NR
        NR->>XMTPD: Return updated list of canonical nodes
        deactivate NR
        XMTPD->>XMTPD: Update peer connections if network changes
    end

    Note over XMTPD, DB: Phase 3: Network Connection
    XMTPD->>CN1: Subscribe to node
    CN1-->>XMTPD: Stream messages
    XMTPD->>CN2: Subscribe to node
    CN2-->>XMTPD: Stream messages
    XMTPD->>CNn: Subscribe to node
    CNn-->>XMTPD: Stream messages

    Note over XMTPD, DB: Phase 4: Network Participation
    XMTPD->>XMTPD: Begin accepting new messages
    XMTPD->>XMTPD: Accept subscriptions from other nodes

    Note over XMTPD: Node fully synchronized and operational
```

## Key features

### Node authentication

- **NFT-based identity**: Node operators authenticate using the private key associated with their NFT
- **Public key registration**: Signing public keys are registered onchain for message verification
- **HTTP endpoints**: Nodes maintain HTTP addresses for peer-to-peer communication

### Network consensus

- **Canonical subset**: Only canonical nodes participate in core network consensus
- **Message consistency**: All canonical nodes maintain identical views of the message history
- **Peer synchronization**: Nodes subscribe to each other's message feeds for consistency

### Operational management

- **Dynamic network**: Nodes can be added or removed from the canonical network without service interruption
- **Performance optimization**: Limited canonical network size ensures optimal performance
- **Monitoring**: Node operators can update their HTTP addresses and service endpoints
