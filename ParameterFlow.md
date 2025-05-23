# XMTP Parameter Flow - Sequence Diagrams

This document illustrates the complete process of setting a parameter in the Settlement Chain Parameter Registry and its journey to being fetched by a contract on an App Chain.

## PlantUML Version

```plantuml
@startuml
title XMTP Cross-Chain Parameter Flow

actor "Admin/Governance" as Admin
participant "Settlement\nParameter Registry" as SPR
actor "User/System" as User
participant "Settlement\nChain Gateway" as SCG
participant "App Chain\nGateway" as ACG
participant "App Chain\nParameter Registry" as APR
participant "App Chain\nContract" as ACC

== Parameter Setting on Settlement Chain ==
Admin -> SPR: 1. call set(key, value)
activate SPR
SPR -> SPR: Store parameter
SPR --> Admin: Emit ParameterSet event
deactivate SPR

== Cross-Chain Parameter Bridging ==
User -> SCG: 2. call sendParametersAsRetryableTickets(keys)
activate SCG
SCG -> SPR: 3. get(key)
activate SPR
SPR --> SCG: Return parameter value
deactivate SPR
SCG -> SCG: 4. Increment nonce
SCG -> SCG: 5. Format payload with parameters and nonce
SCG -> ACG: 6. Submit retryable ticket (receiveParameters)
note right: L2 to L3 cross-chain message\nvia Arbitrum retryable ticket
deactivate SCG

== Parameter Receipt on App Chain ==
activate ACG
ACG -> ACG: 7. Verify sender is settlement chain alias
ACG -> ACG: 8. Check nonce for each parameter
ACG -> APR: 9. call set(key, value) for each parameter
activate APR
APR -> APR: Store parameter
APR --> ACG: Emit ParameterSet event
deactivate APR
ACG -> ACG: 10. Update nonce for each parameter
deactivate ACG

== Parameter Access by App Chain Contract ==
ACC -> ACC: 11. Contract operation requires parameter
activate ACC
ACC -> APR: 12. call get(key)
activate APR
APR --> ACC: Return parameter value
deactivate APR
ACC -> ACC: 13. Process value (type conversion, validation)
ACC -> ACC: 14. Execute logic with parameter value
deactivate ACC

@enduml
```

## Mermaid Version

```mermaid
sequenceDiagram
    title XMTP Cross-Chain Parameter Flow

    actor Admin as Admin/Governance
    participant SPR as Settlement<br>Parameter Registry
    actor User as User/System
    participant SCG as Settlement<br>Chain Gateway
    participant ACG as App Chain<br>Gateway
    participant APR as App Chain<br>Parameter Registry
    participant ACC as App Chain<br>Contract

    rect rgb(240, 240, 240)
    Note over Admin, SPR: Parameter Setting on Settlement Chain
    Admin->>SPR: 1. call set(key, value)
    activate SPR
    SPR->>SPR: Store parameter
    SPR-->>Admin: Emit ParameterSet event
    deactivate SPR
    end

    rect rgb(240, 240, 240)
    Note over User, ACG: Cross-Chain Parameter Bridging
    User->>SCG: 2. call sendParametersAsRetryableTickets(keys)
    activate SCG
    SCG->>SPR: 3. get(key)
    activate SPR
    SPR-->>SCG: Return parameter value
    deactivate SPR
    SCG->>SCG: 4. Increment nonce
    SCG->>SCG: 5. Format payload with parameters and nonce
    SCG->>ACG: 6. Submit retryable ticket (receiveParameters)
    Note right of SCG: L2 to L3 cross-chain message<br>via Arbitrum retryable ticket
    deactivate SCG
    end

    rect rgb(240, 240, 240)
    Note over ACG, APR: Parameter Receipt on App Chain
    activate ACG
    ACG->>ACG: 7. Verify sender is settlement chain alias
    ACG->>ACG: 8. Check nonce for each parameter
    ACG->>APR: 9. call set(key, value) for each parameter
    activate APR
    APR->>APR: Store parameter
    APR-->>ACG: Emit ParameterSet event
    deactivate APR
    ACG->>ACG: 10. Update nonce for each parameter
    deactivate ACG
    end

    rect rgb(240, 240, 240)
    Note over ACC, APR: Parameter Access by App Chain Contract
    ACC->>ACC: 11. Contract operation requires parameter
    activate ACC
    ACC->>APR: 12. call get(key)
    activate APR
    APR-->>ACC: Return parameter value
    deactivate APR
    ACC->>ACC: 13. Process value (type conversion, validation)
    ACC->>ACC: 14. Execute logic with parameter value
    deactivate ACC
    end
```

## Explanation of Parameter Flow Steps

1. **Admin sets parameter on Settlement Chain**:

    - Admin/governance calls `set(key, value)` on Settlement Parameter Registry
    - The registry stores the parameter and emits an event

2. **User initiates parameter bridging**:
    - User/system calls `sendParametersAsRetryableTickets(keys)` on Settlement Chain Gateway
    - This begins the cross-chain bridging process

3-6. **Settlement Chain Gateway prepares and sends parameters**:

- Gateway retrieves current parameter values from Settlement Parameter Registry
- Gateway tracks nonce to ensure ordered parameter updates
- Gateway formats payload containing parameters and nonce
- Gateway submits a retryable ticket to the App Chain Gateway

7-10. **App Chain Gateway receives and processes parameters**:

- App Chain Gateway verifies sender is the Settlement Chain Gateway alias
- Gateway checks nonce for each parameter to prevent replay/out-of-order updates
- Gateway sets parameters in App Chain Parameter Registry
- Gateway updates nonce tracking for each parameter

11-14. **App Chain Contract accesses parameter**:

- During operation, contract needs to access a parameter
- Contract calls `get(key)` on App Chain Parameter Registry
- Contract converts the bytes32 value to the appropriate type
- Contract executes logic using the parameter value

This sequence demonstrates the complete lifecycle of a parameter from its initial setting on the Settlement Chain to its eventual use by a contract on the App Chain, highlighting the cross-chain bridging mechanism using retryable tickets.
