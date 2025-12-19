# Process Steps for Upgrades on Settlement Chain

An **upgrade** refers to upgrading an existing **proxy** to point to a new **implementation** address. Upgrades do not require predicting the new implementation address ahead of time (unlike deployments). The upgrade process deploys a new implementation (or reuses an existing one), deploys a migrator, sets the migrator parameter, and executes the upgrade. All examples below use the environment `staging` so config files are named `testnet-staging.json`.

## STAGE 1 - Setup

### 1. Maintain the root `.env` file to have:

**Admin Configuration (Environment-Specific):**

Admin address type is determined by environment with optional override:

- **testnet-dev**: Defaults to `ADMIN_PRIVATE_KEY`, can override with `ADMIN_ADDRESS_TYPE=FIREBLOCKS`
- **testnet-staging**: Defaults to `ADMIN_PRIVATE_KEY`, can override with `ADMIN_ADDRESS_TYPE=FIREBLOCKS`
- **testnet**: Defaults to Fireblocks (requires `ADMIN` address), can override with `ADMIN_ADDRESS_TYPE=PRIVATE_KEY`
- **mainnet**: Always uses Fireblocks (requires `ADMIN` address, override ignored)

**For Private Key Mode:**

- [ ] `ADMIN_PRIVATE_KEY` used only for writing migrator parameter to parameter registry

**For Fireblocks Mode:**

- [ ] `ADMIN` address must match Fireblocks vault account address
- [ ] Fireblocks environment variables (API key, private key path, RPC URL, vault account IDs) all need set as per `.env.template`.

**Deployer Configuration (Always Required):**

- [ ] `DEPLOYER_PRIVATE_KEY` used for deploying implementations, migrators, and executing migrations

**Other Required:**

- [ ] `BASE_SEPOLIA_RPC_URL` your RPC provider.
- [ ] `ETHERSCAN_API_KEY` your etherscan API key.
- [ ] `ETHERSCAN_API_URL` '`https://api-sepolia.basescan.org/api`'

### 2. Maintain `config/testnet-staging.json` to ensure these have values:

- [ ] `factory` used for creating new contracts
- [ ] `parameterRegistryProxy` used to set migrator address
- [ ] `<contract-being-upgraded>Proxy` this is what gets upgraded

Note: There are no dependencies on `environments/testnet-staging.json` for upgrades.

## STAGE 2 - Upgrade Contracts

In this example we are upgrading `NodeRegistry`.

### 1. Execute the upgrade script:

The upgrade script performs an end-to-end upgrade (deploy implementation or no-op if it exists, deploy migrator, set parameter, execute upgrade). It uses the ADMIN and the DEPLOYER address as appropriate for each step internally:

**For testnet-dev (default private key, can override):**

```bash
# Default (private key)
ENVIRONMENT=testnet-dev forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast

# Override to use Fireblocks
ENVIRONMENT=testnet-dev ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> \
  forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast
```

**For testnet-staging (default private key, can override):**

```bash
# Default (private key)
ENVIRONMENT=testnet-staging forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast

# Override to use Fireblocks
ENVIRONMENT=testnet-staging ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> \
  forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast
```

**For testnet (default Fireblocks, can override):**

```bash
# Default (Fireblocks)
ENVIRONMENT=testnet ADMIN=<fireblocks-admin-address> \
  forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast

# Override to use private key
ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=PRIVATE_KEY \
  forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast
```

**For mainnet (always Fireblocks):**

```bash
ENVIRONMENT=mainnet ADMIN=<fireblocks-admin-address> \
  forge script NodeRegistryUpgrader --rpc-url base_mainnet --sig "UpgradeNodeRegistry()" --broadcast
```

**Note:** When using Fireblocks, the admin operations (setting migrator parameter) will route through Fireblocks and may require approval in the Fireblocks dashboard.

### 2. Update configuration file:

- [ ] Manually copy the `newImpl` field value from the upgrade output to the corresponding `config/testnet-staging.json` file, so that the file shows the correct implementation address. There are no updates required to the `environment/*.json` files because they hold just proxy addresses.

## STAGE 3 - Code Verification

Code verification is only needed once per implementation. To verify the code of upgraded implementations:

```bash
forge verify-contract --chain-id 84532 <implementation address> src/settlement-chain/NodeRegistry.sol:NodeRegistry
```
