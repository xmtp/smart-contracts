# Runbook: Upgrade `DepositSplitter`

Redeploy `DepositSplitter` to a new CREATE2 address across all three testnet environments
(`testnet-dev`, `testnet-staging`, `testnet`). `DepositSplitter` is not upgradeable (no proxy),
so an "upgrade" means deploying a new instance via the `Factory` and updating the addresses
recorded in the repo and in consuming services.

> **Signing note:** `DepositSplitter` deployment uses only `DEPLOYER_PRIVATE_KEY` — no admin
> signing, no proxy, no parameter-registry writes. Fireblocks / admin signers are not involved.

Repeat the per-environment steps below for each of `testnet-dev`, `testnet-staging`, `testnet`.
All three testnet environments live on Base Sepolia (`--chain-id 84532`). Mainnet is not touched
unless it is explicitly behind a version bump.

---

## Per-environment steps

### 1. Set environment

```shell
source .env
export ENVIRONMENT=testnet-dev # then repeat with testnet-staging, then testnet
```

### 2. Predict the new address

```shell
forge script script/Deploy.s.sol:DeployScripts \
  --sig "predictDepositSplitter()" \
  --rpc-url base_sepolia
```

Copy the `Predicted DepositSplitter:` address from the output — referred to below as
`<NEW_DEPOSIT_SPLITTER>`.

### 3. Update `config/${ENVIRONMENT}.json`

Replace the `depositSplitter` value with `<NEW_DEPOSIT_SPLITTER>`. This is the file the deploy
script reads to assert the CREATE2 address before broadcasting.

Keep the old value noted somewhere for reference / rollback.

### 4. Deploy

```shell
forge script script/Deploy.s.sol:DeployScripts \
  --sig "deployDepositSplitter()" \
  --rpc-url base_sepolia \
  --broadcast
```

This will:

- confirm there is no code at `<NEW_DEPOSIT_SPLITTER>`
- deploy via the `Factory` using `DEPLOYER_PRIVATE_KEY`
- assert the deployed address matches the value in `config/${ENVIRONMENT}.json`
- sanity-check `feeToken`, `payerRegistry`, `settlementChainGateway`, and `appChainId` on the
  new instance

### 5. Verify on Basescan

```shell
forge verify-contract \
  --chain-id 84532 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address,address,uint256)" \
    <FEE_TOKEN> <PAYER_REGISTRY> <SETTLEMENT_CHAIN_GATEWAY> <APP_CHAIN_ID>) \
  <NEW_DEPOSIT_SPLITTER> \
  src/settlement-chain/DepositSplitter.sol:DepositSplitter
```

Pull `<FEE_TOKEN>`, `<PAYER_REGISTRY>`, `<SETTLEMENT_CHAIN_GATEWAY>`, and `<APP_CHAIN_ID>` from
`environments/${ENVIRONMENT}.json` (or from the `DepositSplitter` constructor args logged at
deploy time).

### 6. Sanity-check version

```shell
cast call <NEW_DEPOSIT_SPLITTER> "version()(string)" --rpc-url "$BASE_SEPOLIA_RPC_URL"
# expect: "1.0.0"
```

### 7. Update `environments/${ENVIRONMENT}.json`

Replace `depositSplitter` with `<NEW_DEPOSIT_SPLITTER>`. This is the manifest consumed by
off-chain services and snapshots.

### 8. Commit

Commit both `config/${ENVIRONMENT}.json` and `environments/${ENVIRONMENT}.json` so the new
address is recorded in the repo.

---

## After all environments are done

1. Update the funding portal with the three new addresses (`testnet-dev`, `testnet-staging`,
   `testnet`). Mainnet stays as-is unless it is also being bumped.
2. Open the PR for the branch. Nothing else in the contracts repo needs to move.
