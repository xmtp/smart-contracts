# Deploy Factory <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [Overview](#overview)
- [Step 1: Deploy Contract](#step-1-deploy-contract)
- [Step 2: Verify Deployment](#step-2-verify-deployment)
- [Step 3: Verify Source Code](#step-3-verify-source-code)
- [Step 4: Update Config JSON](#step-4-update-config-json)
- [Multi-Chain Deployment](#multi-chain-deployment)
- [Impact on Other Contracts](#impact-on-other-contracts)
  - [Existing deployed contracts](#existing-deployed-contracts)
  - [Future contract deployments](#future-contract-deployments)

## Overview

Deploys a new **Factory** proxy and implementation pair using `DeployFactory.s.sol`.

**Before you begin:** Complete all environment and prerequisite setup in [README.md - Environment and Prerequisites](README.md#3-environment-and-prerequisites), then return here.

**Key difference from other deployments:** Factory is a base-layer contract, but no other contract stores the Factory address as a runtime dependency. A new Factory can be deployed at any time via direct CREATE — deterministic addressing is not required.

**Dependencies managed by this deployment:**

| Method | Parameter Registry Key | Updated Contract | Update Function |
| ------ | ---------------------- | ---------------- | --------------- |
| —      | —                      | —                | —               |

Factory has **no dependency updates** — no contracts store the Factory address at runtime. The Factory is only used at deploy time by other contracts' deployment scripts. After deployment, update `config/<environment>.json` so future scripts use the new Factory.

**Parameter Registry:** No parameter registry updates are required. The two Factory-related keys (`xmtp.factory.paused` and `xmtp.factory.migrator`) are optional governance parameters that apply per-Factory and start at their zero-value defaults (unpaused, no migrator).

## Step 1: Deploy Contract

Deploy the new Factory:

```bash
forge script script/single-deployments/any-chain/DeployFactory.s.sol --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

This:

- Deploys a new Factory implementation (`new Factory(parameterRegistry)`)
- Deploys a new Factory proxy (`new Proxy(implementation)`)
- Initializes the proxy (creates the `Initializable` contract)
- Validates that `parameterRegistry` and `initializableImplementation` are set correctly
- Writes the new proxy address to `environments/<environment>.json` as `settlementChainFactory` or `appChainFactory` (depending on which chain you're connected to)

## Step 2: Verify Deployment

Run the verification script (read-only, no broadcast needed):

```bash
forge script script/single-deployments/any-chain/DeployFactory.s.sol --rpc-url base_sepolia --sig "verifyDeployment()"
```

This reads the Factory address from `environments/<environment>.json` and checks:

- Code exists at the factory address
- `parameterRegistry` matches the expected value
- `initializableImplementation` is non-zero (initialized)
- Prints `contractName`, `version`, and `paused` status

Additionally, verify with direct `cast` calls:

```bash
# Check version
cast call <new-factory-proxy> "version()(string)" --rpc-url $RPC_URL

# Check parameterRegistry
cast call <new-factory-proxy> "parameterRegistry()(address)" --rpc-url $RPC_URL

# Check initializableImplementation
cast call <new-factory-proxy> "initializableImplementation()(address)" --rpc-url $RPC_URL

# Check not paused
cast call <new-factory-proxy> "paused()(bool)" --rpc-url $RPC_URL
```

## Step 3: Verify Source Code

Verify both the Factory implementation and the Proxy on the block explorer. Replace `<chain-id>`, `<parameter-registry>`, `<implementation>`, and `<proxy>` with the values printed by `deployContract()`.

**Factory implementation** (constructor takes `parameterRegistry`):

```bash
forge verify-contract \
  --chain-id 84532 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address)" 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D) \
  0xAb8bE5d1177b1E1f9Da930E5C5cA09F5bE15F4C5 \
  src/any-chain/Factory.sol:Factory
```

**Proxy** (constructor takes the implementation address):

```bash
forge verify-contract \
  --chain-id 84532 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address)" 0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D) \
  0x2bF1F1b5A3c53B8abD3578146148aD1dfBC8491C \
  src/any-chain/Proxy.sol:Proxy
```

## Step 4: Update Config JSON

After successful deployment on **all chains** (settlement + app), update `config/<environment>.json`:

```json
{
  "factory": "<new-factory-proxy>",
  "factoryImplementation": "<new-factory-implementation>",
  "initializableImplementation": "<new-initializable-implementation>",
  ...
}
```

These values were printed by `deployContract()`. This step is critical — all future contract deployments via the single-deployment or upgrade scripts read `factory` from this config.

## Multi-Chain Deployment

Factory exists on both the settlement chain and the app chain. Deploy separately on each:

1. **Settlement chain:**

   ```bash
   forge script DeployFactoryScript --rpc-url $SETTLEMENT_RPC_URL --slow --sig "deployContract()" --broadcast
   ```

   Updates `settlementChainFactory` in `environments/<environment>.json`.

2. **App chain:**

   ```bash
   forge script DeployFactoryScript --rpc-url $APP_CHAIN_RPC_URL --slow --sig "deployContract()" --broadcast
   ```

   Updates `appChainFactory` in `environments/<environment>.json`.

**Multiple environments sharing a chain:** If multiple environments (e.g. `testnet-dev`, `testnet-staging`, `testnet`) share the same settlement chain, you only deploy once per chain. The on-chain Factory is the same; just update each environment's JSON files.

## Impact on Other Contracts

### Existing deployed contracts

No impact. Contracts already deployed through the old Factory continue to work. They do not reference the Factory at runtime.

### Future contract deployments

All proxy addresses deployed through the new Factory will differ from those deployed through the old Factory (because the new Factory has a different `initializableImplementation`, which changes the proxy init code hash). When deploying new contracts via the single-deployment scripts, re-run `predictAddresses()` to get the correct new addresses with the updated `factory` in config.
