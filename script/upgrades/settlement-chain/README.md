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
- [ ] Fireblocks environment variables (API key, private key path, vault account IDs) all need set as per `.env.template`. Omit the `FIREBLOCKS_NOTE` to let the system generate a note.
- [ ] Prefix your forge script command with `npx fireblocks-json-rpc --http --` and use `--rpc-url {}` (the `{}` gets automatically replaced with the proxy URL)
- [ ] Use `--sender <ADMIN_ADDRESS>` flag in forge script commands to specify which address should sign via Fireblocks
- [ ] Use `--unlocked` flag to indicate the sender address is managed by Fireblocks
- [ ] The Fireblocks proxy will forward requests to your actual chain RPC (e.g., Alchemy) while intercepting admin transactions for Fireblocks signing

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

The upgrade script provides two paths:

**Path 1: All-in-one (for non-Fireblocks environments)**

- Uses `Upgrade()` function which performs all steps in a single transaction batch
- Uses ADMIN_PRIVATE_KEY for setting migrator parameter
- Uses DEPLOYER_PRIVATE_KEY for deploying implementations, migrators, and executing migrations

**Path 2: Three-step (for Fireblocks environments)**

- Step 1: `DeployImplementationAndMigrator()` - Deploys implementation and migrator (uses DEPLOYER_PRIVATE_KEY, **never Fireblocks**)
- Step 2: `SetMigratorInParameterRegistry(address)` - Sets migrator in parameter registry (uses ADMIN via **Fireblocks**)
- Step 3: `PerformMigration()` - Executes migration and verifies state (uses DEPLOYER_PRIVATE_KEY, **never Fireblocks**)

**For testnet-dev (default private key, can override):**

```bash
# Default (private key) - All-in-one
ENVIRONMENT=testnet-dev forge script NodeRegistryUpgrader --rpc-url base_sepolia --sig "Upgrade()" --slow --broadcast

# Override to use Fireblocks - Three-step process
# Step 1: Deploy implementation and migrator (non-Fireblocks)
ENVIRONMENT=testnet-dev forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "DeployImplementationAndMigrator()" --broadcast

# Step 2: Set migrator in parameter registry (Fireblocks)
# Note: Copy MIGRATOR_ADDRESS_FOR_STEP_2 and FIREBLOCKS_NOTE_FOR_STEP_2 values from Step 1 output logs
export MIGRATOR_ADDRESS=<value from Step 1 output>
export FIREBLOCKS_NOTE=<value from Step 1 output>
ENVIRONMENT=testnet-dev ADMIN_ADDRESS_TYPE=FIREBLOCKS npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --sig "SetMigratorInParameterRegistry(address)" $MIGRATOR_ADDRESS --broadcast

# Step 3: Perform migration (non-Fireblocks)
ENVIRONMENT=testnet-dev forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "PerformMigration()" --broadcast
```

**For testnet-staging (default private key, can override):**

```bash
# Default (private key) - All-in-one
ENVIRONMENT=testnet-staging forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast

# Override to use Fireblocks - Three-step process
# Step 1: Deploy implementation and migrator (non-Fireblocks)
ENVIRONMENT=testnet-staging forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "DeployImplementationAndMigrator()" --broadcast

# Step 2: Set migrator in parameter registry (Fireblocks)
# Note: Copy MIGRATOR_ADDRESS_FOR_STEP_2 and FIREBLOCKS_NOTE_FOR_STEP_2 values from Step 1 output logs
export MIGRATOR_ADDRESS=<value from Step 1 output>
export FIREBLOCKS_NOTE=<value from Step 1 output>
ENVIRONMENT=testnet-staging ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --sig "SetMigratorInParameterRegistry(address)" $MIGRATOR_ADDRESS --broadcast

# Step 3: Perform migration (non-Fireblocks)
ENVIRONMENT=testnet-staging forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "PerformMigration()" --broadcast
```

**For testnet (default Fireblocks, can override):**

```bash
# Default (Fireblocks) - Three-step process
# Step 1: Deploy implementation and migrator (non-Fireblocks)
ENVIRONMENT=testnet forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "DeployImplementationAndMigrator()" --broadcast

# Step 2: Set migrator in parameter registry (Fireblocks)
# Note: Copy MIGRATOR_ADDRESS_FOR_STEP_2 and FIREBLOCKS_NOTE_FOR_STEP_2 values from Step 1 output logs
export MIGRATOR_ADDRESS=<value from Step 1 output>
export FIREBLOCKS_NOTE=<value from Step 1 output>
ENVIRONMENT=testnet ADMIN=<fireblocks-admin-address> npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryUpgrader --sender <fireblocks-admin-address> --slow --unlocked --rpc-url {} --sig "SetMigratorInParameterRegistry(address)" $MIGRATOR_ADDRESS --broadcast

# Step 3: Perform migration (non-Fireblocks)
ENVIRONMENT=testnet forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "PerformMigration()" --broadcast

# Override to use private key - All-in-one
ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=PRIVATE_KEY \
  forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast
```

**For mainnet (always Fireblocks):**

```bash
# Three-step process (mainnet always uses Fireblocks)
# Step 1: Deploy implementation and migrator (non-Fireblocks)
ENVIRONMENT=mainnet forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "DeployImplementationAndMigrator()" --broadcast

# Step 2: Set migrator in parameter registry (Fireblocks)
# Note: Copy MIGRATOR_ADDRESS_FOR_STEP_2 and FIREBLOCKS_NOTE_FOR_STEP_2 values from Step 1 output logs
export MIGRATOR_ADDRESS=<value from Step 1 output>
export FIREBLOCKS_NOTE=<value from Step 1 output>
ENVIRONMENT=mainnet ADMIN=<fireblocks-admin-address> npx fireblocks-json-rpc --http -- \
  forge script NodeRegistryUpgrader --sender <fireblocks-admin-address> --slow --unlocked --rpc-url {} --sig "SetMigratorInParameterRegistry(address)" $MIGRATOR_ADDRESS --broadcast

# Step 3: Perform migration (non-Fireblocks)
ENVIRONMENT=mainnet forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "PerformMigration()" --broadcast
```

**Important Notes:**

- **Steps 1 and 3 NEVER use Fireblocks** - they always use `DEPLOYER_PRIVATE_KEY` directly
- **Only Step 2 uses Fireblocks** - it requires the Fireblocks JSON-RPC wrapper and `--sender` flag
- **Fireblocks Note**: Step 1 will output `FIREBLOCKS_NOTE_FOR_STEP_2` with the exact note to use. Copy this value and export it as `FIREBLOCKS_NOTE` before running Step 2. The note format is `"setMigrator <ContractName> on <Environment>"` and is automatically generated based on the contract being upgraded. If not set, the Fireblocks JSON-RPC wrapper will use a default note.
- When using Fireblocks for Step 2:
  - Prefix your forge script command with `npx fireblocks-json-rpc --http --` (this starts the proxy and runs your command)
  - Use `--rpc-url {}` in your forge command (the `{}` gets automatically replaced with the proxy URL)
  - Use `--sender <ADMIN_ADDRESS>` to specify which address should sign via Fireblocks
  - Use `--unlocked` flag to indicate the sender address is managed by Fireblocks
  - The Fireblocks proxy intercepts transactions from the `--sender` address and routes them through Fireblocks for signing
  - The proxy forwards all other requests (including deployer operations) to your actual chain RPC (e.g., Alchemy)
  - Admin operations (setting migrator parameter) will route through Fireblocks and may require approval in the Fireblocks dashboard

### 2. Update configuration file:

- [ ] Manually copy the `newImpl` field value from the upgrade output to the corresponding `config/testnet-staging.json` file, so that the file shows the correct implementation address. There are no updates required to the `environment/*.json` files because they hold just proxy addresses.

## STAGE 3 - Code Verification

Code verification is only needed once per implementation. To verify the code of upgraded implementations:

```bash
forge verify-contract --chain-id 84532 <implementation address> src/settlement-chain/NodeRegistry.sol:NodeRegistry
```
