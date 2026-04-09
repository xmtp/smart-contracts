# Deploy Factory <!-- omit from toc -->

## Table of Contents <!-- omit from toc -->

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Step 1: Predict Addresses](#step-1-predict-addresses)
- [Step 2: Deploy Contract](#step-2-deploy-contract)
- [Step 3: Verify Deployment](#step-3-verify-deployment)
- [Step 4: Update Config JSON](#step-4-update-config-json)
- [Multi-Chain Deployment](#multi-chain-deployment)
- [Impact on Other Contracts](#impact-on-other-contracts)
  - [Existing deployed contracts](#existing-deployed-contracts)
  - [Future contract deployments](#future-contract-deployments)
  - [Proxy salt reuse](#proxy-salt-reuse)

## Overview

Deploys a new **Factory** proxy and implementation pair using `DeployFactory.s.sol`.

**Before you begin:** Complete all environment and prerequisite setup in [README.md - Environment and Prerequisites](README.md#3-environment-and-prerequisites), then return here.

**Key difference from other deployments:** Factory is a base-layer contract. Unlike other contracts (NodeRegistry, DistributionManager, etc.) which are deployed _through_ the Factory, a new Factory is deployed _through the old Factory_. The old Factory's CREATE2 mechanism gives the new Factory fully deterministic addresses.

**Dependencies managed by this deployment:**

| Method | Parameter Registry Key | Updated Contract | Update Function |
| ------ | ---------------------- | ---------------- | --------------- |
| —      | —                      | —                | —               |

Factory has **no Step 3a or 3b** — no contracts store the Factory address as a runtime dependency. The Factory is only used at deploy time by other contracts' deployment scripts. After deployment, update `config/<environment>.json` so future scripts use the new Factory.

**Parameter Registry:** No parameter registry updates are required. The two Factory-related keys (`xmtp.factory.paused` and `xmtp.factory.migrator`) are optional governance parameters that apply per-Factory and start at their zero-value defaults (unpaused, no migrator).

## How It Works

The original Factory was deployed via CREATE (nonce-based) during the base deploy. For redeployment, we go through the _old_ Factory's CREATE2:

1. **Implementation** — deployed via `oldFactory.deployImplementation(bytecode)`. The address is fully determined by the bytecode hash (which includes the `parameterRegistry` constructor argument).

2. **Proxy** — deployed via `oldFactory.deployProxy(impl, salt, initCallData)`. The address is determined by deployer + salt. The proxy is atomically initialized, which creates a new `Initializable` contract inside the new Factory.

3. **InitializableImplementation** — created inside `Factory.initialize()` via CREATE from the new proxy. Its address is `computeCreateAddress(newProxy, nonce=1)`.

The `factory` field in `config/<environment>.json` must remain the **old** Factory address during deployment (the script uses it to deploy through). Update it only after deployment succeeds.

## Step 1: Predict Addresses

1. Add `factoryProxySalt` to `config/<environment>.json` with a unique value (e.g. `"Factory_1"`):

   ```json
   {
     "factoryProxySalt": "Factory_1",
     ...
   }
   ```

2. Run the prediction script:

   ```bash
   forge script DeployFactoryScript --rpc-url $RPC_URL --sig "predictAddresses()"
   ```

3. Note the three predicted addresses: `factoryImplementation`, `factory` (proxy), and `initializableImplementation`.

4. If `WARNING: Code already exists at predicted proxy address!` appears, choose a different `factoryProxySalt`.

5. If `NOTE: Code already exists at predicted implementation address` appears, this is expected when the Factory source code hasn't changed (CREATE2 is content-addressed). The deploy will skip the implementation and reuse the existing one.

## Step 2: Deploy Contract

Deploy the new Factory:

```bash
forge script DeployFactoryScript --rpc-url $RPC_URL --slow --sig "deployContract()" --broadcast
```

This:

- Deploys the Factory implementation via the old Factory (or reuses it if bytecode matches)
- Deploys the Factory proxy via the old Factory with the configured salt
- Atomically initializes the proxy (creates the `Initializable` contract)
- Writes the new proxy address to `environments/<environment>.json` as `settlementChainFactory` or `appChainFactory` (depending on which chain you're connected to)

## Step 3: Verify Deployment

Run the verification script (read-only, no broadcast needed):

```bash
forge script DeployFactoryScript --rpc-url $RPC_URL --sig "verifyDeployment()"
```

This checks:

- Code exists at predicted implementation and proxy addresses
- `parameterRegistry` matches the expected value
- `initializableImplementation` is non-zero and matches the predicted address
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

These values were printed by `predictAddresses()` and `deployContract()`. This step is critical — all future contract deployments via the single-deployment or upgrade scripts read `factory` from this config.

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

If the old Factory is at the same address on both chains, and the `parameterRegistryProxy` is at the same address on both chains, and you use the same `factoryProxySalt`, the new Factory will land at the **same address on both chains**. This matches the pattern of the original base deploy.

**Multiple environments sharing a chain:** If multiple environments (e.g. `testnet-dev`, `testnet-staging`, `testnet`) share the same settlement chain, you only deploy once per chain. The on-chain Factory is the same; just update each environment's JSON files.

## Impact on Other Contracts

### Existing deployed contracts

No impact. Contracts already deployed through the old Factory continue to work. They do not reference the Factory at runtime.

### Future contract deployments

All proxy addresses deployed through the new Factory will differ from those deployed through the old Factory (because the new Factory has a different `initializableImplementation`, which changes the CREATE2 proxy init code hash). When deploying new contracts via the single-deployment scripts, re-run `predictAddresses()` to get the correct new addresses with the updated `factory` in config.

### Proxy salt reuse

Proxy salts that were used with the **old** Factory can be reused with the **new** Factory since they produce different addresses (different Factory address + different `initializableImplementation`). However, using new/incremented salts is recommended for clarity.
