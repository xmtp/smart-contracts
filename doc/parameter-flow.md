# XMTP parameter flow - sequence diagrams

This document illustrates the complete process of setting a parameter in the XMTP Settlement Chain parameter registry and its journey to being fetched by a contract on an XMTP App Chain.

## PlantUML version

```plantuml
@startuml
title XMTP Cross-Chain Parameter Flow

actor "User/System" as SCU
actor "Admin/Governance" as Admin
participant "Settlement\nParameter Registry" as SPR
participant "Settlement\nChain Gateway" as SCG
participant "Sequencer\nInfrastructure" as SI
participant "App Chain\nGateway" as ACG
participant "App Chain\nParameter Registry" as APR
participant "App Chain\nContract" as ACC
actor "User/System" as ASU

== 1. Parameter Setting on Settlement Chain ==
Admin -> SPR: set(key, value)

activate SPR
SPR -> SPR: Store parameter
SPR --> Admin: Emit `ParameterSet` event
deactivate SPR

== 2. Cross-Chain Parameter Bridging ==
SCU -> SCG: sendParameters(keys)

activate SCG
SCG -> SPR: get(keys)

activate SPR
SPR --> SCG: values
deactivate SPR

SCG -> SCG: Increment nonce
SCG -> SCG: Format payload with\nparameters and nonce
SCG -> SI: Submit retryable ticket to call\n`appChainGateway.receiveParameters`
SI --> SI: Emit Messaging event
SCG --> SCU: Emit `ParametersSent` event
deactivate SCG

== 3. Parameter Receipt on App Chain ==

SI -> ACG: Try retryable ticket to calling\n`receiveParameters`

activate SI

activate ACG
ACG -> ACG: Verify sender is settlement chain alias
ACG -> ACG: Check nonce for each parameter
ACG -> APR: set(key, value) for each parameter

activate APR
APR -> APR: Store parameter
APR --> ACG: Emit ParameterSet event
deactivate APR

ACG -> ACG: Update nonce for each parameter
ACG --> SI: Emit `ParametersReceived` event
deactivate ACG

deactivate SI

== 4. Parameter Access by App Chain Contract ==
ACU -> ACC: some interaction

activate ACC
ACC -> ACC: Contract operation\nrequires parameter
ACC -> APR: get(key)

activate APR
APR --> ACC: value
deactivate APR

ACC -> ACC: Process value\n(type conversion, validation)
ACC -> ACC: Execute logic\nwith parameter value
ACC --> ACU: Emit event
deactivate ACC

@enduml
```

## Mermaid version

```mermaid
sequenceDiagram
    title XMTP Cross-Chain Parameter Flow

    actor SCU as User/System
    actor Admin as Admin/Governance
    participant SPR as Settlement<br>Parameter Registry
    participant SCG as Settlement<br>Chain Gateway
    participant SI as Sequencer<br>Infrastructure
    participant ACG as App Chain<br>Gateway
    participant APR as App Chain<br>Parameter Registry
    participant ACC as App Chain<br>Contract
    participant ACU as App Chain<br>User

    rect rgb(240, 240, 240)
    Note over Admin, SPR: 1. Parameter Setting on Settlement Chain
    Admin->>SPR: set(key, value)

    activate SPR
    SPR ->> SPR: Store parameter
    SPR -->> Admin: Emit `ParameterSet` event
    deactivate SPR
    end

    rect rgb(240, 240, 240)
    Note over SCU, SI: 2. Cross-Chain Parameter Bridging
    SCU ->> SCG: sendParameters(keys)

    activate SCG
    SCG ->> SPR: get(keys)

    activate SPR
    SPR -->> SCG: values
    deactivate SPR

    SCG ->> SCG: Increment nonce
    SCG ->> SCG: Format payload with<br>parameters and nonce
    SCG ->> SI: Submit retryable ticket to call<br>`appChainGateway.receiveParameters`
    SI --> SI: Emit Messaging event
    SCG -->> SCU: Emit `ParametersSent` event
    deactivate SCG
    end

    rect rgb(240, 240, 240)
    Note over SI, APR: 3. Parameter Receipt on App Chain
    SI ->> ACG: Try retryable ticket to calling<br>`receiveParameters`

    activate ACG
    ACG ->> ACG: Verify sender is settlement chain alias
    ACG ->> ACG: Check nonce for each parameter
    ACG ->> APR: set(key, value) for each parameter

    activate APR
    APR ->> APR: Store parameter
    APR -->> ACG: Emit ParameterSet event
    deactivate APR

    ACG ->> ACG: Update nonce for each parameter
    ACG -->> SI: Emit `ParametersReceived` event
    deactivate ACG

    end

    rect rgb(240, 240, 240)
    Note over APR, ACU: 4. Parameter Access by App Chain Contract
    ACU ->> ACC: some interaction
    activate ACC
    ACC ->> ACC: Contract operation requires parameter
    ACC ->> APR: get(key)
    activate APR
    APR -->> ACC: value
    deactivate APR
    ACC ->> ACC: Process value (type conversion, validation)
    ACC ->> ACC: Execute logic with parameter value
    ACC -->> ACU: Emit event
    deactivate ACC
    end
```

## Explanation of parameter flow steps

1. To set a parameter, on the Settlement Chain:

   - Admin/governance calls `set(key, value)` on Parameter Registry
   - The registry stores the parameter and emits an event

2. To bridge parameters to the app chain, on the Settlement Chain:

   - any User/system calls `sendParameters(keys)` on the Gateway
   - This begins the cross-chain bridging process
   - Gateway retrieves current parameter values from Parameter Registry
   - Gateway tracks nonce to ensure ordered parameter updates
   - Gateway formats payload containing parameters and nonce
   - Gateway submits a retryable ticket to the "Sequencer Infrastructure" (inbox, then bridge)

3. To receive parameters on the App Chain, on the App Chain:

   - Sequencer Infrastructure submit the retryable ticket and tries the call and calldata once
   - Gateway verifies sender is the Settlement Chain Gateway alias
   - Gateway checks nonce for each parameter to prevent replay/out-of-order updates
   - Gateway sets parameters in Parameter Registry
   - Gateway updates nonce tracking for each parameter

4. To access a parameter, on the App Chain:
   - Some call is made to an app chain contract
   - During operation, if the contract needs to access a parameter, it calls `get(key)` on Parameter Registry
   - Contract converts and validates the bytes32 value to the appropriate type
   - Contract executes logic using the parameter value

This sequence demonstrates the complete lifecycle of a parameter from its initial setting on the XMTP Settlement Chain to its eventual use by a contract on the XMTP App Chain, highlighting the cross-chain bridging mechanism using retryable tickets.
