# Payers

Payers are entities (typically app developers, agents, or service providers) who need to fund their accounts to pay for XMTP network services such as message broadcasting and identity updates. The XMTP protocol provides multiple funding mechanisms to accommodate different user preferences and technical capabilities.

## Funding Methods

### Manual Funding Process

The traditional manual funding process involves multiple steps across both settlement and application chains:

1. **Wallet Setup**: Create wallets on both the settlement chain (Base L2) and application chain (XMTP L3)
2. **Token Wrapping**: Deposit USDC into the `FeeToken` contract, receiving `xUSD` tokens in exchange at a 1:1 ratio
3. **Settlement Chain Funding**: Deposit `xUSD` tokens into the `PayerRegistry` to cover costs for off-chain message processing and settlement operations
4. **Application Chain Funding**: Transfer `xUSD` tokens to the application chain payer's wallet to cover gas costs for publishing blockchain messages and identity updates

### Simplified Funding with DepositSplitter

For improved user experience, the `DepositSplitter` contract provides convenience functions that streamline the funding process:

- **`deposit()`**: Allows payers to split deposits between the `PayerRegistry` and application chain in a single transaction
- **`depositWithPermit()`**: Enables gasless transactions using EIP-2612 permit signatures, eliminating the need for separate approval transactions

This approach reduces the complexity from multiple transactions across different contracts to a single, atomic operation.

### Funding Portal Integration

The Funding Portal provides a user-friendly interface that:

- Simplifies the funding process through an intuitive web interface
- Allows payers to connect their wallets directly using standard wallet connection protocols
- Abstracts away the technical complexity of cross-chain operations
- Provides real-time balance tracking across both settlement and application chains

## DepositSplitter Workflow

The following diagram illustrates the complete process of a payer using the DepositSplitter contract to fund their accounts across both chains:

```mermaid
sequenceDiagram
    title XMTP Payer Funding via DepositSplitter

    participant Payer as Payer
    participant USDC as USDC Token
    participant DS as DepositSplitter
    participant FT as FeeToken
    participant PR as PayerRegistry
    participant SCG as SettlementChainGateway
    participant ACG as AppChainGateway
    participant AC as App Chain

    Note over Payer, AC: Phase 1: Setup and Approval
    Payer->>USDC: approve(DepositSplitter, totalAmount)
    activate USDC
    USDC-->>Payer: Approval confirmed
    deactivate USDC

    Note over Payer, AC: Phase 2: Deposit Splitting
    Payer->>DS: deposit(address payer_, uint96 payerRegistryAmount_, address appChainRecipient_, uint96 appChainAmount_, uint256 appChainGasLimit_, uint256 appChainMaxFeePerGas_) external
    activate DS

    Note over DS, FT: Step 1: Wrap USDC to xUSD
    DS->>USDC: transferFrom(payer, DepositSplitter, totalAmount)
    activate USDC
    USDC-->>DS: Transfer successful
    deactivate USDC

    DS->>FT: deposit(totalAmount)
    activate FT
    FT->>FT: Mint xUSD tokens
    FT-->>DS: xUSD tokens minted
    deactivate FT

    Note over DS, PR: Step 2: Fund PayerRegistry (Settlement Chain)
    alt payerRegistryAmount > 0
        DS->>PR: deposit(payer, payerRegistryAmount)
        activate PR
        PR->>PR: Credit payer account
        PR-->>DS: Deposit successful
        deactivate PR
    end

    Note over DS, AC: Step 3: Bridge to App Chain
    alt appChainAmount > 0
        DS->>SCG: deposit(appChainId, appChainRecipient, appChainAmount, gasLimit, maxFeePerGas)
        activate SCG
        SCG->>SCG: Create retryable ticket
        SCG->>ACG: Cross-chain message (retryable ticket)
        activate ACG
        ACG->>AC: Mint xUSD for appChainRecipient
        activate AC
        AC-->>ACG: Tokens minted
        deactivate AC
        ACG-->>SCG: Bridge successful
        deactivate ACG
        SCG-->>DS: Cross-chain deposit initiated
        deactivate SCG
    end

    DS-->>Payer: Deposit splitting completed
    deactivate DS

    Note over Payer, AC: Result: Payer funded on both chains
    Note over PR: Settlement Chain: Payer account credited
    Note over AC: App Chain: Recipient wallet funded
```
