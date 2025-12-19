# Process Steps for Upgrades on App Chain

An **app chain upgrade** refers to upgrading an existing **proxy** on an app chain to point to a new **implementation** address. App chain upgrades require a three-step process that spans both the settlement chain and the app chain:

1. **Prepare** the new implementation and migrator on the app chain, that is, deploy them.
2. **Bridge** the migrator parameter from the settlement chain to the app chain.
3. **Upgrade** the contract on the app chain.

All examples below use the environment `staging`, so config files are named `testnet-staging.json`.

## Token Requirements

| Step       | Executed on      | Address  | baseETH (settlement)  | xUSD (settlement)     | xUSD (app chain)          |
| ---------- | ---------------- | -------- | --------------------- | --------------------- | ------------------------- |
| 1. Prepare | App Chain        | DEPLOYER | -                     | -                     | yes for deployment tx gas |
| 2. Bridge  | Settlement Chain | ADMIN    | yes for param reg tx  | -                     | -                         |
| 2. Bridge  | Settlement Chain | DEPLOYER | yes for bridge tx gas | yes to give to bridge | -                         |
| 3. Upgrade | App Chain        | DEPLOYER | -                     | -                     | yes for upgrade tx gas    |

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

- [ ] `ADMIN` address (must match Fireblocks vault account address)
- [ ] Fireblocks environment variables (API key, private key path, vault account IDs) all need set as per `.env.template`. Omit the `FIREBLOCKS_NOTE` to let the system generate a note.
- [ ] Prefix your forge script command with `npx fireblocks-json-rpc --http --` and use `--rpc-url {}` (the `{}` gets automatically replaced with the proxy URL)
- [ ] Use `--sender <ADMIN_ADDRESS>` flag in forge script commands to specify which address should sign via Fireblocks
- [ ] Use `--unlocked` flag to indicate the sender address is managed by Fireblocks
- [ ] The Fireblocks proxy will forward requests to your actual chain RPC (e.g., Alchemy) while intercepting admin transactions for Fireblocks signing

**Deployer Configuration (Always Required):**

- [ ] `DEPLOYER_PRIVATE_KEY` used for deploying implementations, migrators, bridging, and executing migrations

**Other Required:**

- [ ] `BASE_SEPOLIA_RPC_URL` the RPC provider for the settlement chain.
- [ ] `XMTP_ROPSTEN_RPC_URL` the RPC for the app chain.

### 2. Maintain `config/testnet-staging.json` to ensure these have values:

- [ ] `factory` used for creating new contracts
- [ ] `parameterRegistryProxy` used to set migrator address
- [ ] `<contract-being-upgraded>Proxy` this is what gets upgraded

Note: There are no dependencies on `environments/testnet-staging.json` for upgrades.

## STAGE 2 - Upgrade Contracts

App chain upgrades require three steps that execute on different chains.

**NB: Take care to use the correct `--rpc-url` for each step!**

### Example: Upgrade Identity Update Broadcaster

#### Step 1 - Prepare new implementation on app chain (uses DEPLOYER)

Deploy the new implementation and migrator on the app chain. This step always uses `DEPLOYER_PRIVATE_KEY`:

**For testnet-dev (default private key):**

```bash
# Default (private key)
ENVIRONMENT=testnet-dev forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast

# Override to use Fireblocks (Note: Prepare step uses DEPLOYER, so Fireblocks not needed here)
ENVIRONMENT=testnet-dev ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
```

**For testnet-staging (default private key):**

```bash
# Default (private key)
ENVIRONMENT=testnet-staging forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast

# Override to use Fireblocks (Note: Prepare step uses DEPLOYER, so Fireblocks not needed here)
ENVIRONMENT=testnet-staging ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
```

**For testnet (default Fireblocks):**

```bash
# Note: Prepare step uses DEPLOYER, so Fireblocks not needed here
ENVIRONMENT=testnet ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
```

**For mainnet (always Fireblocks):**

```bash
# Note: Prepare step uses DEPLOYER, so Fireblocks not needed here
ENVIRONMENT=mainnet ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_mainnet --slow --sig "Prepare()" --broadcast
```

- [ ] Note the migrator address from the output. This will be used in Step 2.

#### Step 2 - Bridge the migrator parameter (uses ADMIN and DEPLOYER)

Bridge the migrator parameter from the settlement chain to the app chain. ADMIN sets the migrator in parameter registry (uses Fireblocks if configured), then DEPLOYER approves fee token and bridges:

**For testnet-dev (default private key):**

```bash
# Default (private key)
ENVIRONMENT=testnet-dev forge script IdentityUpdateBroadcasterUpgrader --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS_FROM_STEP_1> --broadcast

# Override to use Fireblocks
npx fireblocks-json-rpc --http -- \
  ENVIRONMENT=testnet-dev ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --sender <fireblocks-admin-address> --slow --unlocked --rpc-url {} --sig "Bridge(address)" <MIGRATOR_ADDRESS_FROM_STEP_1> --broadcast
```

**For testnet-staging (default private key):**

```bash
# Default (private key)
ENVIRONMENT=testnet-staging forge script IdentityUpdateBroadcasterUpgrader --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS_FROM_STEP_1> --broadcast

# Override to use Fireblocks
npx fireblocks-json-rpc --http -- \
  ENVIRONMENT=testnet-staging ADMIN_ADDRESS_TYPE=FIREBLOCKS ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --sender <fireblocks-admin-address> --slow --unlocked --rpc-url {} --sig "Bridge(address)" <MIGRATOR_ADDRESS_FROM_STEP_1> --broadcast
```

**For testnet (default Fireblocks):**

```bash
npx fireblocks-json-rpc --http -- \
  ENVIRONMENT=testnet ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --sender <fireblocks-admin-address> --slow --unlocked --rpc-url {} --sig "Bridge(address)" <MIGRATOR_ADDRESS_FROM_STEP_1> --broadcast
```

**For mainnet (always Fireblocks):**

```bash
npx fireblocks-json-rpc --http -- \
  ENVIRONMENT=mainnet ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --sender <fireblocks-admin-address> --slow --unlocked --rpc-url {} --sig "Bridge(address)" <MIGRATOR_ADDRESS_FROM_STEP_1> --broadcast
```

- [ ] Note the `migratorParameterKey` from the output (e.g., `xmtp.identityUpdateBroadcaster.migrator`).
- [ ] **If using Fireblocks**:
  - Prefix your forge script command with `npx fireblocks-json-rpc --http --` (this starts the proxy and runs your command)
  - Use `--rpc-url {}` in your forge command (the `{}` gets automatically replaced with the proxy URL)
  - Use `--sender <ADMIN_ADDRESS>` to specify which address should sign via Fireblocks for admin operations
  - Use `--unlocked` flag to indicate the sender address is managed by Fireblocks
  - The Fireblocks proxy intercepts transactions from the `--sender` address and routes them through Fireblocks for signing
  - The proxy forwards all other requests (including deployer operations) to your actual chain RPC (e.g., Alchemy)
  - Check Fireblocks dashboard for transaction approval request for the admin operation
  - The deployer operations (fee token approval and bridging) will still use `DEPLOYER_PRIVATE_KEY` and sign normally - they bypass Fireblocks

#### Step 3 - Verify bridge and execute upgrade (uses DEPLOYER)

- [ ] Manually verify the bridge completed successfully by checking the parameter registry on the app chain. The parameter key from Step 2 should show the migrator address from Step 1.

Example verification URL:

```
https://xmtp-ropsten.explorer.alchemy.com/address/0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D?tab=read_write_proxy
```

Execute the upgrade on the app chain. This step always uses `DEPLOYER_PRIVATE_KEY`:

**For testnet-dev:**

```bash
ENVIRONMENT=testnet-dev forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
```

**For testnet-staging:**

```bash
ENVIRONMENT=testnet-staging forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
```

**Note:** Step 3 (Upgrade) always uses `DEPLOYER_PRIVATE_KEY` regardless of admin address type configuration.

**For testnet:**

```bash
ENVIRONMENT=testnet ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
```

**For mainnet:**

```bash
ENVIRONMENT=mainnet ADMIN=<fireblocks-admin-address> \
  forge script IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_mainnet --slow --sig "Upgrade()" --broadcast
```

- [ ] Note the new implementation address from the output.

#### Step 4 - Update configuration file

- [ ] Manually copy the new implementation address from Step 3 to the corresponding `config/testnet-staging.json` file, so that the file shows the correct implementation address.

## STAGE 3 - Code Verification

Code verification is only needed once per implementation. The automated verification script is idempotent and will skip previously verified contracts:

```bash
./dev/verify-base xmtp_ropsten alchemy
```

If any contracts were not picked up by the automated script, verify them manually. Example for Identity Update Broadcaster:

```bash
forge verify-contract \
  --verifier blockscout \
  --verifier-url https://xmtp-ropsten.explorer.alchemy.com/api/ \
  --chain-id 351243127 \
  --constructor-args $(cast abi-encode "constructor(address)" "0xB2EA84901BC8c2b18Da7a51db1e1Ca2aAeDf844D") \
  <IMPLEMENTATION_ADDRESS> \
  src/app-chain/IdentityUpdateBroadcaster.sol:IdentityUpdateBroadcaster
```

In the above, the address `0xB2EA...` is the parameter registry address.
