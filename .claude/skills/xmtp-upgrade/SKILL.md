---
name: xmtp-upgrade
description: >
  Upgrade an XMTP protocol contract via the multi-step forge script workflow,
  supporting both wallet and Fireblocks signing modes across settlement and app
  chains. Use when user asks to "upgrade a contract", "deploy a new
  implementation", "upgrade NodeRegistry", "upgrade PayerRegistry", or mentions
  upgrading any XMTP contract like GroupMessageBroadcaster, Gateway, RateRegistry,
  DistributionManager, FeeToken, or ParameterRegistry.
argument-hint: [contract] [environment] [signing-mode]
metadata:
  author: XMTP
  version: 1.0.0
---

The user wants to upgrade a contract. Parse from their request:

- **Contract name**: which contract to upgrade (see contract list below)
- **Environment**: testnet-dev, testnet-staging, testnet, or mainnet
- **Signing mode** (optional): wallet or fireblocks. If not specified, use the environment default from the README.

## Contract list

Settlement chain contracts (use upgrader script name in parentheses):
- NodeRegistry (NodeRegistryUpgrader)
- PayerRegistry (PayerRegistryUpgrader)
- PayerReportManager (PayerReportManagerUpgrader)
- RateRegistry (RateRegistryUpgrader)
- DistributionManager (DistributionManagerUpgrader)
- FeeToken (FeeTokenUpgrader)
- SettlementChainGateway (SettlementChainGatewayUpgrader)
- SettlementChainParameterRegistry (SettlementChainParameterRegistryUpgrader)

App chain contracts (use upgrader script name in parentheses):
- AppChainGateway (AppChainGatewayUpgrader)
- AppChainParameterRegistry (AppChainParameterRegistryUpgrader)
- GroupMessageBroadcaster (GroupMessageBroadcasterUpgrader)
- IdentityUpdateBroadcaster (IdentityUpdateBroadcasterUpgrader)

Accept fuzzy names from the user (e.g. "node registry", "payer report manager", "gateway on settlement") and resolve to the correct upgrader script name.

## Procedure

1. **Verify repo is clean.** Run `forge clean && yarn prettier && yarn build && yarn test`. If any command fails (e.g. a test failure), **stop immediately** and tell the user to fix the issue before retrying. After the commands succeed, run `git status` — if there are any uncommitted changes (e.g. prettier reformatted a file), **stop immediately** and tell the user to commit or resolve the changes first. Do not proceed with the upgrade until the repo is clean and all tests pass.

2. Determine the **chain** from the contract name (settlement-chain or app-chain).

3. Determine the **signing mode**. Read the environment defaults table in the appropriate README:
   - Settlement chain: `script/upgrades/settlement-chain/README.md`
   - App chain: `script/upgrades/app-chain/README.md`

4. Read the appropriate workflow README:
   - Settlement chain + wallet: `script/upgrades/settlement-chain/README-wallet.md`
   - Settlement chain + fireblocks: `script/upgrades/settlement-chain/README-fireblocks.md`
   - App chain + wallet: `script/upgrades/app-chain/README-wallet.md`
   - App chain + fireblocks: `script/upgrades/app-chain/README-fireblocks.md`

5. Read `config/<environment>.json` to verify the required addresses exist (factory, parameterRegistryProxy, and the relevant contract proxy address).

6. Read `.env` and make sure the ADMIN address is uncommented in the block appropriate for the chosen signing method. If we are using signing method FIREBLOCKS then we expect ADMIN to be uncommented near the other FIREBLOCKS env vars, and commented out near the ADMIN_PRIVATE_KEY. If we are using signing method WALLET then it is vice-versa. This is because forge picks up the first ADMIN it finds when reading the .env file.

7. Follow the steps in the README exactly, substituting the correct contract upgrader script name. For each step:
   - **Compose the full command** with all flags and arguments filled in.
   - **Show the command** to the user, explain what it does, and **run it in the same turn**. Do not ask for approval in chat — Claude Code's tool permission prompt already handles that.
   - **After running**, parse the output for any values needed in subsequent steps (especially `MIGRATOR_ADDRESS_FOR_STEP_2`, `FIREBLOCKS_NOTE_FOR_STEP_2`, and `newImpl` addresses).
   - **Carry those values forward** automatically — do not ask the user to copy-paste from output.

8. For **Fireblocks steps** specifically:
   - After running the Fireblocks command, remind the user: "Please approve the transaction in the Fireblocks console. Let me know when it's confirmed."
   - **Wait for the user to confirm** before proceeding to the next step.

9. For **app chain bridge steps**: after bridging, offer to run the verification command to check the migrator arrived on the app chain. Wait for bridge finalization if needed.

10. After the final step succeeds:
    - Parse the new implementation address from the output.
    - Update `config/<environment>.json` with the new implementation address in the appropriate field.
    - Show the user the verify-contract command from the Post-Upgrade section.

## Important rules

- Never run a `--broadcast` command unless the user has asked for a broadcast (not a dry run). The tool permission prompt serves as the approval gate — do not also ask in chat.
- Never edit `.env` by yourself, always ask the user to do that.
- Source `.env` into the shell (`source .env`) before the first forge command so that variables like `$ADMIN` are available for shell expansion (e.g. in `--sender $ADMIN`). The `.env` file is a dotenv file that forge also reads internally, but command-line arguments require the shell to expand them first.
- Set `ENVIRONMENT` and `ADMIN_ADDRESS_TYPE` env vars before the first forge command.
- If any step fails, stop and discuss with the user before retrying or continuing.
- If the user asks to skip the state check, set `SKIP_STATE_CHECK=true` in the environment.

## Examples

Example 1: Dry-run upgrade with Fireblocks
User says: "upgrade NodeRegistry on testnet-dev using fireblocks, do a dry run"
Actions:
1. Verify repo is clean (`forge clean && yarn prettier && yarn build && yarn test`)
2. Read READMEs, config, and .env
3. Verify .env has Fireblocks ADMIN uncommented
4. Run Step 1 (deploy new implementation) without `--broadcast`
5. Show results without submitting any on-chain transaction

Example 2: Full upgrade with wallet signing
User says: "upgrade the payer report manager on testnet-staging"
Actions:
1. Resolve to `PayerReportManagerUpgrader` on settlement chain
2. Use wallet signing (testnet-staging default)
3. Run all steps with `--broadcast`, carrying forward addresses between steps
4. Update `config/testnet-staging.json` with new implementation address

Example 3: App chain contract upgrade
User says: "upgrade GroupMessageBroadcaster on testnet-dev"
Actions:
1. Identify as app-chain contract
2. Read app-chain upgrade READMEs
3. Run upgrade steps including bridge step
4. Verify migrator arrived on app chain after bridge finalization

## Troubleshooting

Error: Tests fail during repo cleanliness check
Cause: Existing test failures or code changes in the working tree
Solution: Stop and ask the user to fix failing tests or commit changes before retrying

Error: `git status` shows uncommitted changes after prettier
Cause: Files were reformatted by prettier
Solution: Stop and ask the user to commit the formatting changes first

Error: Fireblocks transaction times out
Cause: Approver didn't act within the `--timeout` window (default 3600s)
Solution: Re-run the command — Fireblocks will create a new transaction for approval

Error: Wrong ADMIN address picked up by forge
Cause: `.env` has the wrong ADMIN uncommented for the chosen signing mode
Solution: Ask the user to swap which ADMIN line is commented/uncommented in `.env`

Error: Bridge verification shows migrator hasn't arrived
Cause: Bridge finalization takes a few minutes
Solution: Wait 2-5 minutes and re-run the verification command
