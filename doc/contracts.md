# XMTP Network Contracts

## System Design

XMTP is a cross-chain messaging protocol with two primary components:

- **Settlement Chain**: Manages payments, node registry, and system parameters (typically deployed on Base).
- **App Chain**: Handles the actual message inclusion and identity update broadcasting functionality (XMTP L3 chain).

The system uses proxied upgradeable contracts with a cross-chain parameter bridging mechanism.

## Deployment Process

Specific deployment instructions can be found in the [deployment document](./deployment.md).

The deployment follows a precise order to handle contract interdependencies:

1. **Factory Deployment** on both chains to enable deterministic address creation.
2. **Parameter Registry Deployment** on settlement chain (admin-controlled).
3. **Pre-compute Gateway Addresses** for cross-references.
4. **Parameter Registry Deployment** on app chain (gateway-controlled).
5. **Gateway Deployments** on both chains that reference each other and their respective parameter registries.
6. **Initial Parameter Configuration** on settlement chain followed by parameter bridging.
7. **Broadcaster Deployments** on app chain that use the app chain parameter registry.
8. **Service Contract Deployments** (Payer, Rate, Node registries) on settlement chain.

## Key Components

### Settlement Chain

- **NodeRegistry**: ERC721-based registry for network nodes (mints NFTs starting at ID 100, incrementing by 100).
- **PayerRegistry**: Manages payer deposits, withdrawals, and fee payment for messaging.
- **RateRegistry**: Sets fees for message and storage operations.
- **SettlementChainParameterRegistry**: Stores system parameters, defined by an admin and/or governance.
- **SettlementChainGateway**: Bridges parameters to app chain via retryable tickets.
- **FeeToken**: ERC20-compliant wrapped token serving as the primary medium of exchange for protocol fees. Backed 1:1 by an underlying stablecoin (USDC). Features permit functionality for gasless approvals and supports both direct deposits and deposits-for-others patterns.
- **DepositSplitter**: Convenience contract that enables payers to split deposits between the PayerRegistry and app chains in a single transaction. Allows depositing FeeToken or underlying stablecoin simultaneously into the PayerRegistry (for settlement chain operations) and bridging funds to app chains via the SettlementChainGateway. Supports permit-based approvals for gasless transactions and handles the complexity of coordinating deposits across multiple contracts.
- **DistributionManager**: Allows verified node operators to claim their portion of fees earned from network operations, with fees distributed equally among all active nodes defined in each PayerReport. Reserves a configurable portion (protocolFeeRate) for the protocol treasury or designated recipient, and manages both FeeToken and underlying token withdrawals for protocol fees.

### App Chain

- **GroupMessageBroadcaster**: Broadcasts forced-inclusion group messages with sequencing and size constraints.
- **IdentityUpdateBroadcaster**: Broadcasts identity updates with similar constraints.
- **AppChainParameterRegistry**: Stores parameters received from settlement chain.
- **AppChainGateway**: Receives parameters from settlement chain gateway.

### Cross-Chain Infrastructure

- **Factory**: Creates implementations and proxies with deterministic addresses on both chains.
- **Proxy**: Transparent proxy with default implementation.
- **Initializable**: First proxied implementation of all proxies, aiding in determinism and atomic initialization.
- **Migratable**: Abstract contract for migration/upgrade functionality.

## Parameter Flow

The parameter system uses a key-value storage mechanism:

1. **Parameter Definition**:

   - Keys are human-readable strings stored as bytes (e.g., "xmtp.nodeRegistry.admin").
   - Values are stored as bytes32, supporting various data types (numbers, addresses, booleans).

2. **Parameter Setting on Settlement Chain**:

   - Admin calls `set()` on `SettlementChainParameterRegistry`.
   - Parameters are stored in a mapping and events are emitted.

3. **Cross-Chain Parameter Bridging**:

   - `SettlementChainGateway`'s `sendParametersAsRetryableTickets()` packages parameters upon user request.
   - The gateway fetches current values from the parameter registry and creates a retryable ticket.
   - Ticket targets `AppChainGateway`'s `receiveParameters()` function.
   - Nonce tracking ensures proper ordering of parameter updates on the app chain.

4. **Parameter Receipt on App Chain**:

   - `AppChainGateway` receives parameters (only from `SettlementChainGateway`'s alias address).
   - For each received parameter, `AppChainGateway` calls `set()` on `AppChainParameterRegistry` after nonce validation.
   - Parameters are now available for app chain contracts.

5. **Parameter Access by Contracts**:
   - Contracts define parameter keys in their interfaces.
   - They store an immutable reference to their local (settlement chain or app chain) parameter registry.
   - When needed, contracts call `get()` on the parameter registry to retrieve current values.
   - Contracts include update functions to locally store some parameter copies for cheaper logic execution.

## Data Flow

1. **Node Management**:

   - `NodeRegistry` mints NFTs for nodes and tracks canonical network membership.
   - Admin adds/removes nodes to/from canonical network.
   - Node operators provide messaging services and earn commission.

2. **Payment Flow**:

   - Payers deposit tokens into `PayerRegistry` on settlement chain.
   - `RateRegistry` tracks historical and current fees for message services.
   - Settler role deducts fees from user balances.

3. **Messaging Flow**:
   - Identity updates and force-inclusion messages are broadcasted via broadcasters on app chain.
   - Each broadcast increments a sequence ID for ordering.
   - Broadcasters enforce payload size limits from parameter registry.
   - Messages are only emitted as events for nodes to process (not stored).

The architecture creates a robust cross-chain messaging platform with centralized parameter management on the settlement chain while enabling efficient message broadcasting on the app chain.

## Design Rationale

The XMTP smart contract architecture embodies several key design decisions that optimize for scalability, flexibility, and future-proofing:

### L2/L3 Chain Separation

The system is strategically split between an L2 settlement chain and L3 app chains for several technical and economic reasons:

- **Throughput Optimization**: Message and identity broadcast operations occur at extremely high frequencies compared to economic operations, making cheaper L3 transactions essential for cost efficiency.
- **Scalability Through Sharding**: As an L3 chain approaches capacity limits, the system can horizontally scale by sharding across multiple L3 app chains.
- **Separation of Concerns**: Economic and administrative functions (node registration, payments) remain on the more secure and economically-interoperable L2, while high-volume messaging operations happen on specialized L3s.
- **Cost Efficiency**: The significantly lower transaction costs on L3s make high-throughput messaging economically viable.

### Parameter Registry Architecture

The parameter registry pattern was selected to achieve maximum flexibility with minimal coupling:

- **Contract Agnosticism**: The parameter registry implementation remains completely agnostic to existing or future contracts that might consume its parameters.
- **Flexible Parameter Definition**: Parameters can be defined and constructed with significant flexibility through the key-value architecture.
- **Minimal Coupling**: Contracts only need to know their parameter keys and the parameter registry address.
- **Governance Readiness**: Future governance systems will have a clear and consistent way to propose, vote on, and implement parameter changes across the entire system.
- **Contract Evolution Support**: As contracts are upgraded or newly created, the parameter system accommodates them without restructuring.

### Cross-Chain Communication

Retryable tickets were chosen as the cross-chain messaging mechanism due to reliability requirements:

- **Guaranteed Delivery**: Among Arbitrum's L2→L3 communication methods, retryable tickets are the only one guaranteeing message delivery.
- **Failure Recovery**: If initial delivery attempts fail due to gas or other issues, the system allows retrying the ticket.
- **Conditional Execution**: The mechanism minimizes absolute failures of parameter bridging due to gas price issues, and increases consistency and predictability.
- **Nonce Tracking**: Prevents out-of-order parameter updates that could create temporarily undesired states.

### Storage Pattern Implementation

The ERC-7201 namespaced storage pattern with strategic use of immutables offers significant advantages:

- **Upgrade Efficiency**: Provides clean storage isolation when handling upgrades, migrations, and inheritance.
- **Storage Lookup Reduction**: Using immutables for frequently accessed, yet unlikely to change, values (like parameter registry, gateway, or token addresses) eliminates expensive storage reads as they are inlined in the bytecode.
- **Proxy Compatibility**: Despite using immutables in proxy-targeted implementations (somewhat unorthodox), the approach yields substantial gas savings at the cost of needing to upgraded if an immutable value needs to be changed.

### Updateable Parameters

Parameters are designed to be mutable rather than fixed for several operational reasons:

- **Runtime Tuning**: Parameters may need adjustment to accommodate changes in throughput or costs.
- **Governance Integration**: Future governance decisions can be implemented through parameter updates.
- **Emergency Response**: Critical parameters can be adjusted in response to security incidents.
- **Upgrade Coordination**: The migrator parameter pattern allows contracts to delegate upgrade control in a coordinated fashion, with flexibility in its complexity.
- **Adaptability**: As the network evolves, parameters can be tuned to optimize performance without redeployment.

### Migration/Upgrade Pattern

The XMTP contracts implement a custom migration pattern that differs from standard proxy upgrade approaches:

- **Separation of Concerns**: The `Migratable` pattern decouples implementation logic from migration logic, allowing each to evolve independently.
- **External Migration Definition**: Unlike OpenZeppelin's `upgradeToAndCall` pattern, the XMTP approach allows the logic defining a proxy's migration process to be defined outside the implementation contract.
- **Implementation Simplicity**: New implementations can focus solely on their core functionality without embedding complex migration logic for all possible predecessor versions.
- **Flexible Migration Options**: The pattern enables specialized migration paths that can:
  - Upgrade a proxy to a new implementation with appropriate state transformations.
  - Apply storage modifications without changing the implementation (for hotfixes).
  - Handle migrations from multiple different predecessor versions.
- **Parameter-Controlled Upgrades**: The migrator address is itself a parameter in the registry, providing a clean mechanism for governance to control upgrade processes.
- **Migration Security**: The migration logic is contained in a dedicated contract that can undergo specific security analysis for the migration process.

This approach represents a thoughtful evolution of proxy upgrade patterns, recognizing that implementation logic and migration logic have different concerns, lifecycles, and security considerations.

## System Considerations

The XMTP architecture involves important tradeoffs and considerations in its design. Understanding these factors provides deeper insight into the architectural decisions.

### Security Considerations

1. **Parameter Governance Evolution**:

   - The initial centralization in the Parameter Registry (controlled by multi-sig) will transition to token-based governance.
   - This planned evolution balances immediate operational needs with long-term decentralization goals.

2. **Cross-Chain Security Model**:

   - Retryable tickets provide recoverability for parameter bridging.
   - The system assumes incentive alignment between parameter initiators and those ensuring completion of cross-chain operations.
   - Cross-chain parameter synchronization delays are an accepted limitation, prioritizing eventual consistency over immediacy.

3. **Migration Security Approach**:

   - The external migration pattern introduces additional flexibility at the cost of requiring careful scrutiny.
   - Migration contracts undergo the same authorization checks as direct implementation upgrades.

4. **Parameter Encoding**:

   - Parameters are expected to be correctly encoded as bytes32, and within valid ranges for consuming contracts.
   - Parameter validation can be implemented in consuming contracts to reject invalid values, providing an additional security layer.

### Developer and Operational Considerations

1. **Deployment Complexity Management**:

   - The interdependent deployment sequence can be simplified through address precomputation.
   - Making app chain contracts more tolerant during initialization reduces deployment coordination requirements.
   - Scripts and thorough testing are essential for managing the deployment process.

2. **Gas and Cross-Chain Operations**:

   - Retryable tickets provide better recoverability compared to alternatives, despite gas estimation challenges.
   - The system accepts the potential need for retries as a reasonable tradeoff for guaranteed deliverability.

3. **Upgrade Orchestration**:

   - Coordinating upgrades across chains requires sophisticated operational procedures.
   - Well-written, decoupled contracts help make upgrades more manageable.
   - The flexible migration pattern provides tools for handling complex upgrade scenarios.

4. **Protocol Evolution**:
   - The system is designed to accommodate future changes through parameter updates and contract upgrades.
   - The separation between economic operations (settlement chain) and messaging operations (app chain) allows each aspect to evolve at its own pace.
   - The architecture's flexibility supports progressive improvements without re-implementation or excess upgrades or migrations.
