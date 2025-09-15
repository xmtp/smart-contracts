# Payers

Payers are entities (typically app developers, agents, or service providers) who need to fund their accounts to pay for XMTP network services such as message broadcasting and identity updates. The XMTP protocol provides multiple funding mechanisms to accommodate different user preferences and technical capabilities.

## Funding Methods

### Manual Funding Process

The traditional manual funding process involves multiple steps across both settlement and application chains:

1. **Wallet Setup**: Create wallets on both the settlement chain (Base L2) and application chain (XMTP L3)
2. **Token Wrapping**: Deposit USDC into the `FeeToken` contract, receiving `xUSD` tokens in exchange at a 1:1 ratio
   - This can be skipped if the payer uses the `Underlying`-suffixed functions throughout the protocol.
3. **Settlement Chain Funding**: Deposit `xUSD` tokens into the `PayerRegistry` to cover costs for off-chain message processing and settlement operations
4. **Application Chain Funding**: Transfer `xUSD` tokens to the application chain payer's wallet to cover gas costs for publishing blockchain messages and identity updates

### Simplified Funding with DepositSplitter

For improved user experience, the `DepositSplitter` contract provides convenience functions that streamline the funding process:

- **`deposit()`**: Allows payers to split deposits of `xUSD` between the `PayerRegistry` and `SettlementChainGateway` (to be bridged to an app chain) in a single transaction, assuming they have approved the `DepositSplitter` to spend their `xUSD` tokens.
- **`depositWithPermit()`**: Allows payers to perform the above split `deposit()` without having to precede the transaction with an approval transaction.
- **`depositFromUnderlying()`**: Allows payers to deposit underlying fee tokens (i.e. `USDC`) into the `PayerRegistry` and `SettlementChainGateway` (to be bridged to an app chain) in a single transaction, assuming they have approved the `DepositSplitter` to spend their underlying fee tokens.
- **`depositFromUnderlyingWithPermit()`**: Allows payers to perform the above split `depositFromUnderlying()` without having to precede the transaction with an approval transaction.

This approach reduces the complexity from multiple transactions across different contracts to a single, atomic operation.

### Funding Portal Integration

The Funding Portal provides a user-friendly interface that:

- Simplifies the funding process through an intuitive web interface
- Allows payers to connect their wallets directly using standard wallet connection protocols
- Abstracts away the technical complexity of cross-chain operations
- Provides real-time balance tracking across both settlement and application chains

## DepositSplitter Workflow

The following diagram illustrates the complete process of a payer using the DepositSplitter contract to fund their accounts across both chains, sourced from `USDC`:

```mermaid
sequenceDiagram
    title XMTP Payer Funding via DepositSplitter

    participant Payer as Payer
    participant USDC as USDC Token
    participant DS as DepositSplitter
    participant FT as FeeToken
    participant PR as PayerRegistry
    participant SCG as SettlementChainGateway
    participant I as Inbox

    Note over Payer: Phase 1: Setup and Approval
    Payer->>USDC: approve(DepositSplitter, totalAmount)
    activate USDC
    USDC-->>Payer: Approval confirmed
    deactivate USDC

    Note over Payer: Phase 2: Deposit Splitting
    Payer->>DS: deposit(address payer_, uint96 payerRegistryAmount_, address appChainRecipient_, uint96 appChainAmount_, uint256 appChainGasLimit_, uint256 appChainMaxFeePerGas_)
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

        PR->>FT: transferFrom(DepositSplitter, PayerRegistry, payerRegistryAmount)
        activate FT
        FT-->>PR: Transfer successful
        deactivate FT

        PR->>PR: Credit payer account
        PR-->>DS: Deposit successful
        deactivate PR
    end

    Note over DS, I: Step 3: Bridge to App Chain
    alt appChainAmount > 0
        DS->>SCG: deposit(appChainId, appChainRecipient, appChainAmount, gasLimit, maxFeePerGas)
        activate SCG

        SCG->>FT: transferFrom(DepositSplitter, SettlementChainGateway, appChainAmount)
        activate FT
        FT-->>SCG: Transfer successful
        deactivate FT

        SCG->>FT: approve(Inbox, appChainAmount)
        activate FT
        FT-->>SCG: Approval successful
        deactivate FT

        SCG->>I: Create retryable ticket (Cross-chain message)

        I->>FT: transferFrom(SettlementChainGateway, Inbox, appChainAmount)
        activate FT
        FT-->>I: Transfer successful
        deactivate FT

        I->>SCG: Message Id

        SCG->>DS: Deposit successful
    end

    DS-->>Payer: Deposit splitting completed
    deactivate DS
```
