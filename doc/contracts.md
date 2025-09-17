# XMTP network contracts

## System design

XMTP is a cross-chain messaging protocol with two primary components:

- **XMTP Settlement Chain**: Manages payments, node registry, and system parameters (typically deployed on Base).
- **XMTP App Chain**: Handles the actual message inclusion and identity update broadcasting functionality (XMTP L3 chain).

The system uses proxied upgradeable contracts with a cross-chain parameter bridging mechanism.

## Deployment process

Specific deployment instructions can be found in the [deployment document](./deployment.md).

Dependencies and interactions between contracts are documented in the [dependencies document](./dependencies.md).

The deployment follows a precise order to handle contract interdependencies:

1. **Factory deployment** on both chains to enable deterministic address creation.
2. **Parameter registry deployment** on the XMTP Settlement Chain (admin-controlled).
3. **Pre-compute gateway addresses** for cross-references.
4. **Parameter registry deployment** on the XMTP App Chain (gateway-controlled).
5. **Gateway deployments** on both chains that reference each other and their respective parameter registries.
6. **Initial parameter configuration** on the XMTP Settlement Chain followed by parameter bridging.
7. **Broadcaster deployments** on the XMTP App Chain that use the app chain parameter registry.
8. **Service contract deployments** (Payer, Rate, Node registries) on the XMTP Settlement Chain.

## Key components

### Settlement chain

- **NodeRegistry**: ERC721-based registry for network nodes (mints NFTs starting at ID 100, incrementing by 100).
- **PayerRegistry**: Manages payer deposits, withdrawals, and fee payment for messaging.
- **RateRegistry**: Sets fees for message and storage operations.
- **SettlementChainParameterRegistry**: Stores system parameters, defined by an admin and/or governance.
- **SettlementChainGateway**: Bridges parameters to the XMTP App Chain via retryable tickets.
- **FeeToken**: ERC20-compliant wrapped token serving as the primary medium of exchange for protocol fees. Backed 1:1 by an underlying stablecoin (USDC). Features permit functionality for gasless approvals and support both direct deposits and deposits-for-others patterns.
- **DepositSplitter**: Convenience contract that enables payers to split deposits between the PayerRegistry and XMTP App Chains in a single transaction. Allows depositing FeeToken or underlying stablecoin simultaneously into the PayerRegistry (for XMTP Settlement Chain operations) and bridging funds to XMTP App Chains via the SettlementChainGateway. Supports permit-based approvals for gasless transactions and handles the complexity of coordinating deposits across multiple contracts.
- **DistributionManager**: Allows verified node operators to claim their portion of fees earned from network operations, with fees distributed equally among all active nodes defined in each PayerReport. Reserves a configurable portion (protocolFeeRate) for the protocol treasury or designated recipient, and manages both FeeToken and underlying token withdrawals for protocol fees.

### XMTP App Chain

- **GroupMessageBroadcaster**: Broadcasts forced-inclusion group messages with sequencing and size constraints.
- **IdentityUpdateBroadcaster**: Broadcasts identity updates with similar constraints.
- **AppChainParameterRegistry**: Stores parameters received from the XMTP Settlement Chain.
- **AppChainGateway**: Receives parameters from the XMTP Settlement Chain gateway.

### Cross-chain infrastructure

- **Factory**: Creates implementations and proxies with deterministic addresses on both XMTP Settlement and App Chains.
- **Proxy**: Transparent proxy with default implementation.
- **Initializable**: First proxied implementation of all proxies, aiding in determinism and atomic initialization.
- **Migratable**: Abstract contract for migration/upgrade functionality.

## Parameter flow

The parameter system uses a key-value storage mechanism:

1. **Parameter definition**:

   - Keys are human-readable strings stored as bytes (e.g., "xmtp.nodeRegistry.admin").
   - Values are stored as bytes32, supporting various data types (numbers, addresses, booleans).

2. **Parameter setting on the XMTP Settlement Chain**:

   - Admin calls `set()` on `SettlementChainParameterRegistry`.
   - Parameters are stored in a mapping and events are emitted.

3. **Cross-chain parameter bridging**:

   - `SettlementChainGateway`'s `sendParameters()` packages parameters upon user request.
   - The gateway fetches current values from the parameter registry and creates a retryable ticket.
   - Ticket targets `AppChainGateway`'s `receiveParameters()` function.
   - Nonce tracking ensures proper ordering of parameter updates on the XMTP App Chain.

4. **Parameter receipt on the XMTP App Chain**:

   - `AppChainGateway` receives parameters (only from `SettlementChainGateway`'s alias address).
   - For each received parameter, `AppChainGateway` calls `set()` on `AppChainParameterRegistry` after nonce validation.
   - Parameters are now available for XMTP App Chain contracts.

5. **Parameter access by contracts**:
   - Contracts define parameter keys in their interfaces.
   - They store an immutable reference to their local (XMTP Settlement or App Chain) parameter registry.
   - When needed, contracts call `get()` on the parameter registry to retrieve current values.
   - Contracts include update functions to locally store some parameter copies for cheaper logic execution.

## Data flow

1. **Node management**:

   - `NodeRegistry` mints NFTs for nodes and tracks canonical network membership.
   - Admin adds/removes nodes to/from canonical network.
   - Node operators provide messaging services and earn commission.

2. **Payment flow**:

   - Payers deposit tokens into `PayerRegistry` on the XMTP Settlement Chain.
   - `RateRegistry` tracks historical and current fees for message services.
   - Settler role deducts fees from user balances.

3. **Messaging flow**:
   - Identity updates and force-inclusion messages are broadcast via broadcasters on the XMTP App Chain.
   - Each broadcast increments a sequence ID for ordering.
   - Broadcasters enforce payload size limits from parameter registry.
   - Messages are only emitted as events for nodes to process (not stored).

The architecture creates a robust cross-chain messaging platform with centralized parameter management on the XMTP Settlement Chain while enabling efficient message broadcasting on the XMTP App Chain.

## Design rationale

The XMTP smart contract architecture embodies several key design decisions that optimize for scalability, flexibility, and future-proofing:

### L2/L3 chain separation

The system is strategically split between an L2 XMTP Settlement Chain and L3 XMTP App Chains for several technical and economic reasons:

- **Throughput optimization**: Message and identity broadcast operations occur at extremely high frequencies compared to economic operations, making cheaper L3 transactions essential for cost efficiency.
- **Scalability through sharding**: As an L3 chain approaches capacity limits, the system can horizontally scale by sharding across multiple L3 XMTP App Chains.
- **Separation of concerns**: Economic and administrative functions (node registration, payments) remain on the more secure and economically-interoperable L2, while high-volume messaging operations happen on specialized L3s.
- **Cost efficiency**: The significantly lower transaction costs on L3s make high-throughput messaging economically viable.

### Fee token

For any L3 app chain to not be forever dependent and coupled to a specific third-party stablecoin, we instead chose to wrap a specific stablecoin into a "fee token" that can eventually be upgraded to support several stablecoins or just one other stablecoin. 

The migration for either of these scenarios is not yet designed, as it may not ever be needed, especially if the need for app chains at all goes away before the need to no longer rely on a originally chosen underlying stablecoin (USDC). 

Such a migration simply needs to be possible. However, to reduce user interactions/complexity, all contracts that handle the Fee Token to or from a user (either by pulling tokens in or transferring them out) should also handle the underlying stablecoin (including wrapping/unwrapping) for convenience. 

Throughout the codebase, “underlying fee token” refers to the stablecoin wrapped into the Fee Token, so the `FromUnderlying`-suffixed or `IntoUnderlying`-suffixed functions distinguish default Fee Token handling from the explicit underlying token interactions.

Another benefit of the Fee Token being the first-party token is that on testnets, we can deploy our own mintable mock underlying stablecoin that can be used to test many of the value-related functionality, without relying on a third-party stablecoin.

### Parameter registry architecture

The parameter registry pattern was selected to achieve maximum flexibility with minimal coupling:

- **Contract agnosticism**: The parameter registry implementation remains completely agnostic to existing or future contracts that might consume its parameters.
- **Flexible parameter definition**: Parameters can be defined and constructed with significant flexibility through the key-value architecture.
- **Minimal coupling**: Contracts only need to know their parameter keys and the parameter registry address.
- **Governance readiness**: Future governance systems will have a clear and consistent way to propose, vote on, and implement parameter changes across the entire system.
- **Contract evolution support**: As contracts are upgraded or newly created, the parameter system accommodates them without restructuring.

### Cross-chain communication

Retryable tickets were chosen as the cross-chain messaging mechanism due to reliability requirements:

- **Guaranteed delivery**: Among Arbitrum's L2→L3 communication methods, retryable tickets are the only one guaranteeing message delivery.
- **Failure recovery**: If initial delivery attempts fail due to gas or other issues, the system allows retrying the ticket.
- **Conditional execution**: The mechanism minimizes absolute failures of parameter bridging due to gas price issues, and increases consistency and predictability.
- **Nonce tracking**: Prevents out-of-order parameter updates that could create temporarily undesired states.

### Storage pattern implementation

The ERC-7201 namespaced storage pattern with strategic use of immutables offers significant advantages:

- **Upgrade efficiency**: Provides clean storage isolation when handling upgrades, migrations, and inheritance.
- **Storage lookup reduction**: Using immutables for frequently accessed, yet unlikely to change, values (like parameter registry, gateway, or token addresses) eliminates expensive storage reads as they are inlined in the bytecode.
- **Proxy compatibility**: Despite using immutables in proxy-targeted implementations (somewhat unorthodox), the approach yields substantial gas savings at the cost of needing to an upgrade (i.e., new implementation) if an immutable value must change.

### Updateable parameters

Parameters are designed to be mutable rather than fixed for several operational reasons:

- **Runtime tuning**: Parameters may need adjustment to accommodate changes in throughput or costs.
- **Governance integration**: Future governance decisions can be implemented through parameter updates.
- **Emergency response**: Critical parameters can be adjusted in response to security incidents.
- **Upgrade coordination**: The migrator parameter pattern allows contracts to delegate upgrade control in a coordinated fashion, with flexibility in its complexity.
- **Adaptability**: As the network evolves, parameters can be tuned to optimize performance without redeployment.

### Migration/upgrade pattern

The XMTP contracts implement a custom migration pattern that differs from standard proxy upgrade approaches:

- **Separation of concerns**: The `Migratable` pattern decouples implementation logic from migration logic, allowing each to evolve independently.
- **External migration definition**: Unlike OpenZeppelin's `upgradeToAndCall` pattern, the XMTP approach allows the logic defining a proxy's migration process to be defined outside the implementation contract.
- **Implementation simplicity**: New implementations can focus solely on their core functionality without embedding complex migration logic for all possible predecessor versions.
- **Flexible migration options**: The pattern enables specialized migration paths that can:
  - Upgrade a proxy to a new implementation with appropriate state transformations.
  - Apply storage modifications without changing the implementation (for hotfixes).
  - Handle migrations from multiple different predecessor versions.
- **Parameter-controlled upgrades**: The migrator address is itself a parameter in the registry, providing a clean mechanism for governance to control upgrade processes.
- **Migration security**: The migration logic is contained in a dedicated contract that can undergo specific security analysis for the migration process.

This approach represents a thoughtful evolution of proxy upgrade patterns, recognizing that implementation logic and migration logic have different concerns, lifecycles, and security considerations.

## System considerations

The XMTP architecture involves important tradeoffs and considerations in its design. Understanding these factors provides deeper insight into the architectural decisions.

### Security considerations

1. **Parameter governance evolution**:

   - The initial centralization in the Parameter Registry (controlled by multi-sig) will transition to token-based governance.
   - This planned evolution balances immediate operational needs with long-term decentralization goals.

2. **Cross-chain security model**:

   - Retryable tickets provide recoverability for parameter bridging.
   - The system assumes incentive alignment between parameter initiators and those ensuring completion of cross-chain operations.
   - Cross-chain parameter synchronization delays are an accepted limitation, prioritizing eventual consistency over immediacy.

3. **Migration security approach**:

   - The external migration pattern introduces additional flexibility at the cost of requiring careful scrutiny.
   - Migration contracts undergo the same authorization checks as direct implementation upgrades.

4. **Parameter encoding**:

   - Parameters are expected to be correctly encoded as bytes32, and within valid ranges for consuming contracts.
   - Parameter validation can be implemented in consuming contracts to reject invalid values, providing an additional security layer.

### Developer and operational considerations

1. **Deployment complexity management**:

   - The interdependent deployment sequence can be simplified through address precomputation.
   - Making XMTP App Chain contracts more tolerant during initialization reduces deployment coordination requirements.
   - Scripts and thorough testing are essential for managing the deployment process.

2. **Gas and cross-chain operations**:

   - Retryable tickets provide better recoverability compared to alternatives, despite gas estimation challenges.
   - The system accepts the potential need for retries as a reasonable tradeoff for guaranteed deliverability.

3. **Upgrade orchestration**:

   - Coordinating upgrades across chains requires sophisticated operational procedures.
   - Well-written, decoupled contracts help make upgrades more manageable.
   - The flexible migration pattern provides tools for handling complex upgrade scenarios.

4. **Protocol evolution**:
   - The system is designed to accommodate future changes through parameter updates and contract upgrades.
   - The separation between economic operations (XMTP Settlement Chain) and messaging operations (XMTP App Chain) allows each aspect to evolve at its own pace.
   - The architecture's flexibility supports progressive improvements without re-implementation or excess upgrades or migrations.
