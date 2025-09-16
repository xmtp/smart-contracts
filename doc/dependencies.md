# XMTP smart contracts - communication dependency diagram

This diagram illustrates the communication dependencies between contracts in the XMTP smart contracts ecosystem, focusing exclusively on which contracts call functions on other contracts (not inheritance).

## Contract communication diagram

```mermaid
flowchart TD
    classDef appchain fill:#9ff,stroke:#333,stroke-width:1px
    classDef settlementchain fill:#f96,stroke:#333,stroke-width:1px
    classDef external fill:#ddd,stroke:#333,stroke-width:1px

    %% App-chain contracts
    AppChainGateway[App Chain <br> Gateway]:::appchain
    AppChainParameterRegistry[App Chain <br> Parameter Registry]:::appchain
    GroupMessageBroadcaster[Group Message <br> Broadcaster]:::appchain
    IdentityUpdateBroadcaster[Identity Update <br> Broadcaster]:::appchain

    %% Settlement-chain contracts
    SettlementChainGateway[Settlement Chain <br> Gateway]:::settlementchain
    SettlementChainParameterRegistry[Settlement Chain <br> Parameter Registry]:::settlementchain
    NodeRegistry[Node <br> Registry]:::settlementchain
    PayerRegistry[Payer <br> Registry]:::settlementchain
    RateRegistry[Rate <br> Registry]:::settlementchain

    %% External contracts
    IERC20Token[IERC20 <br> Token]:::external
    IERC20Inbox[IERC20 <br> Inbox]:::external

    %% Communication dependencies - Settlement Chain
    SettlementChainGateway -.->|"get(bytes) <br> get(bytes[])"|SettlementChainParameterRegistry
    SettlementChainGateway -.->|"transferFrom() <br> approve()"|IERC20Token
    SettlementChainGateway -.->|"depositERC20() <br> sendContractTransaction() <br> createRetryableTicket()"|IERC20Inbox

    NodeRegistry -.->|"get(bytes)"|SettlementChainParameterRegistry

    PayerRegistry -.->|"get(bytes)"|SettlementChainParameterRegistry
    PayerRegistry -.->|"balanceOf() <br> transfer() <br> transferFrom()"|IERC20Token

    RateRegistry -.->|"get(bytes)"|SettlementChainParameterRegistry

    %% Communication dependencies - App Chain
    AppChainGateway -.->|"set(bytes, bytes32)"|AppChainParameterRegistry
    AppChainGateway -.->|"get(bytes)"|AppChainParameterRegistry

    GroupMessageBroadcaster -.->|"get(bytes)"|AppChainParameterRegistry

    IdentityUpdateBroadcaster -.->|"get(bytes)"|AppChainParameterRegistry

    %% Cross-chain communication
    SettlementChainGateway -..->|"Cross-chain call to <br> receiveParameters()"|AppChainGateway

    %% Legend
    subgraph Legend
        AC[App <br> Chain <br> Contract]:::appchain
        SC[Settlement <br> Chain <br> Contract]:::settlementchain
        EX[External <br> Contract]:::external
        A[Contract A]
        B[Contract B]
        A -.->|"functionCall()"|B
    end
```

## Key communication dependencies

### XMTP Settlement Chain contracts

1. **Settlement chain gateway**:

    - Calls `get(bytes)` on **Settlement Chain Parameter Registry** to retrieve a migrator address
    - Calls `get(bytes[])` on **Settlement Chain Parameter Registry** to retrieve parameter values for bridging
    - Calls `depositERC20()`, `sendContractTransaction()`, and `createRetryableTicket()` on **IERC20 Inbox** for cross-chain messaging
    - Calls `transferFrom()`, and `approve()` on **IERC20 Token** for token operations
    - Prepares cross-chain calls to **App Chain Gateway**'s `receiveParameters()` function via retryable tickets

2. **Node registry**:

    - Calls `get(bytes)` on **Settlement Chain Parameter Registry** to retrieve admin, node manager, and migrator addresses

3. **Payer registry**:

    - Calls `get(bytes)` on **Settlement Chain Parameter Registry** to retrieve settler, fee distributor, minimum deposit, withdraw lock period, and a migrator address
    - Calls `balanceOf()`, `transfer()`, and `transferFrom()` on **IERC20 Token** for token operations

4. **Rate registry**:

    - Calls `get(bytes)` on **Settlement Chain Parameter Registry** to retrieve message fee, storage fee, congestion fee, target rate per minute, and a migrator address

### XMTP App Chain contracts

1. **App chain gateway**:

    - Calls `set(bytes, bytes32)` on **App Chain Parameter Registry** to store parameters received from the XMTP Settlement Chain
    - Calls `get(bytes)` on **App Chain Parameter Registry** to retrieve a migrator address

2. **Group message broadcaster**:

    - Calls `get(bytes)` on **App Chain Parameter Registry** to retrieve min/max payload sizes, pause status, and a migrator address

3. **Identity update broadcaster**:

    - Calls `get(bytes)` on **App Chain Parameter Registry** to retrieve min/max payload sizes, pause status, and a migrator address

## Primary communication flows

1. **Parameter bridging flow**:

    - **Settlement Chain Gateway** reads parameters from **Settlement Chain Parameter Registry**
    - **Settlement Chain Gateway** sends parameters to **App Chain Gateway** via retryable tickets
    - **App Chain Gateway** receives parameters and updates **App Chain Parameter Registry**
    - XMTP App Chain contracts read parameters from **App Chain Parameter Registry**

2. **Token operations flow**:

    - **Payer Registry** interacts with **IERC20 Token** for deposits and withdrawals
    - **Settlement Chain Gateway** uses **IERC20 Inbox** for cross-chain messaging

3. **Configuration access pattern**:
    - All contracts retrieve their configuration from their respective chain's parameter registry
    - This creates a consistent pattern where contract behavior is determined by centrally managed parameters
