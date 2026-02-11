---
name: xmtp-upgrade
description: Upgrade an XMTP protocol contract via the multi-step forge script workflow, supporting both wallet and Fireblocks signing modes across settlement and app chains.
argument-hint: [contract] [environment] [signing-mode]
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
- Set `ENVIRONMENT` and `ADMIN_ADDRESS_TYPE` env vars before the first forge command.
- If any step fails, stop and discuss with the user before retrying or continuing.
- If the user asks to skip the state check, set `SKIP_STATE_CHECK=true` in the environment.
