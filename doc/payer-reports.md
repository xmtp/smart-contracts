# Payer reports

As described in the [architecture](./architecture.md) document, the MLS standard defines multiple message types. In the XMTP network, two of those types are directly published to the blockchain, and payers through the `Gateway` service pay directly for the gas used to publish them.

The other three types of messages are published to `xmtpd` nodes through offchain APIs, and each `xmtpd` node tracks all the messages published through them and creates a detailed report every 12 hours. This is called a `PayerReport`, and it's essential to the economic model and sustainability of the network. These reports are managed through the [PayerReportManager contract](../src/settlement-chain/PayerReportManager.sol).

## PayerReport structure

A complete `PayerReport` contains the following fields:

```json
{
  "originatorNodeId": 100,
  "startSequenceId": 0,
  "endSequenceId": 1000,
  "endMinuteSinceEpoch": 12345678,
  "feesSettled": 0,
  "offset": 0,
  "isSettled": false,
  "protocolFeeRate": 100,
  "payersMerkleRoot": "0x12345678abcdef...",
  "nodeIds": [100, 200, 300]
}
```

### Field descriptions

- **`originatorNodeId`**: ID of the node that originated this report (NFT ID from NodeRegistry)
- **`startSequenceId`**: Starting sequence number for messages in this report
- **`endSequenceId`**: Ending sequence number for messages in this report
- **`endMinuteSinceEpoch`**: Timestamp marking the end of the reporting period
- **`feesSettled`**: Total fees already settled from this report (starts at 0)
- **`offset`**: Next index in the Merkle tree to be processed (for partial settlements)
- **`isSettled`**: Whether the entire report has been processed
- **`protocolFeeRate`**: Protocol fee percentage (in basis points) at time of submission
- **`payersMerkleRoot`**: Merkle tree root containing all payer fee data
- **`nodeIds`**: List of active canonical nodes during the reporting period

## EIP-712 signature hash

The report hash for signing is calculated using [EIP-712](https://eips.ethereum.org/EIPS/eip-712) structured data hashing:

**Type hash:**

```solidity
keccak256("PayerReport(uint32 originatorNodeId,uint64 startSequenceId,uint64 endSequenceId,uint32 endMinuteSinceEpoch,bytes32 payersMerkleRoot,uint32[] nodeIds)")
```

**Final digest:**

```solidity
keccak256(
  abi.encodePacked(
    "\x19\x01",
    DOMAIN_SEPARATOR,
    keccak256(abi.encode(PAYER_REPORT_TYPEHASH, ...report_data))
  )
)
```

The domain separator is defined by the [ERC5267](../src/abstract/ERC5267.sol) implementation.

## Merkle tree structure

The `payersMerkleRoot` is computed offchain using a specialized [merkle package](https://github.com/xmtp/xmtpd/tree/main/pkg/merkle) in `xmtpd`.

Each leaf in the Merkle tree contains:

```yaml
payer_address: owed_amount
```

The tree supports sequential proofs, allowing for partial settlement of reports in batches rather than requiring full settlement in a single transaction.

## Report lifecycle

### 1. Report generation (offchain)

```mermaid
sequenceDiagram
    participant Node as xmtpd Node
    participant Peers as Other Canonical Nodes
    participant DB as Local Database

    Note over Node, DB: Every 12 Hours
    Node->>DB: Query messages in sequence range
    Node->>Node: Calculate fees for each payer
    Node->>Node: Build Merkle tree from payer fees
    Node->>Node: Create PayerReport structure
    Node->>Node: Generate EIP-712 digest
    Node->>Node: Sign digest with node private key
    Node->>Peers: Share report with canonical nodes
    Peers->>Node: Receive signatures from peers
    Note over Node: Report ready for submission
```

### 2. Attestation and signing

Before submission, PayerReports must be signed by a majority of canonical nodes:

**Signature requirements:**

- Must have signatures from `(canonicalNodeCount / 2) + 1` nodes
- Only signatures from canonical nodes are valid
- Signing node IDs must be ordered and unique
- Each signature is verified against the node's registered signer address

**Signature structure:**

```solidity
struct PayerReportSignature {
  uint32 nodeId; // Node ID from NodeRegistry
  bytes signature; // ECDSA signature of the report digest
}
```

### 3. Report submission

```mermaid
sequenceDiagram
    participant Submitter as Report Submitter
    participant PRM as PayerReportManager
    participant NR as NodeRegistry
    participant Storage as Contract Storage

    Submitter->>PRM: submit(originatorNodeId, startSeq, endSeq, endTime, merkleRoot, nodeIds, signatures)
    activate PRM

    Note over PRM: Validation Phase
    PRM->>PRM: Verify sequence ID continuity
    PRM->>PRM: Validate sequence ID ordering

    Note over PRM: Signature Verification
    PRM->>PRM: Generate EIP-712 digest
    loop For each signature
        PRM->>NR: Check if node is canonical
        PRM->>PRM: Recover signer from signature
        PRM->>NR: Verify signer matches node's registered signer
    end
    PRM->>PRM: Verify sufficient valid signatures (>50% of canonical nodes)

    Note over PRM: Storage
    PRM->>Storage: Store PayerReport
    PRM->>Submitter: Return payerReportIndex
    PRM->>PRM: Emit PayerReportSubmitted event
    deactivate PRM
```

### 4. Settlement process

Settlement can occur in batches, allowing large reports to be processed incrementally:

```mermaid
sequenceDiagram
    participant Settler as Settlement Caller
    participant PRM as PayerReportManager
    participant Merkle as Sequential Merkle Proofs
    participant PR as PayerRegistry
    participant DM as DistributionManager

    Settler->>PRM: settle(originatorNodeId, payerReportIndex, payerFees, proofElements)
    activate PRM

    Note over PRM: Validation
    PRM->>PRM: Verify report exists and not fully settled
    PRM->>Merkle: Verify sequential merkle proof
    PRM->>PRM: Update offset for next settlement batch

    Note over PRM: Fee Settlement
    PRM->>PR: settleUsage(payerFees)
    activate PR
    PR->>PR: Deduct fees from payer balances
    PR->>DM: Transfer fees to DistributionManager
    PR->>PRM: Return total fees settled
    deactivate PR

    Note over PRM: State Updates
    PRM->>PRM: Update feesSettled amount
    PRM->>PRM: Check if report fully settled
    PRM->>Settler: Emit PayerReportSubsetSettled event
    deactivate PRM
```

## Key features

### Sequential processing

- Reports must be submitted with continuous sequence IDs (no gaps)
- Each originator node maintains its own sequence of reports
- Settlement can occur in batches using sequential Merkle proofs

### Consensus mechanism

- Requires majority consensus from canonical nodes (>50%)
- Invalid signatures are ignored, not rejected
- Signature verification uses ECDSA recovery and node registry validation

### Economic integration

- Protocol fee rate is captured at submission time
- Fees are settled directly from payer balances in PayerRegistry
- Settled fees are transferred to DistributionManager for node operator rewards

### Partial settlement support

- Large reports can be settled in multiple transactions
- Offset tracking ensures sequential processing of Merkle tree leaves
- Settlement completion is automatically detected and marked

## Error handling

The system includes comprehensive error handling for various failure scenarios:

- **Invalid sequence IDs**: Reports with gaps or incorrect ordering are rejected
- **Insufficient signatures**: Reports without majority consensus are rejected
- **Invalid signatures**: Signatures from non-canonical nodes or with incorrect recovery are ignored
- **Settlement failures**: Failed settlement calls to PayerRegistry are reverted with detailed error information
- **Merkle proof failures**: Invalid proofs or out-of-order settlements are rejected

This robust error handling ensures the integrity of the economic settlement process while providing clear feedback for debugging and recovery.
