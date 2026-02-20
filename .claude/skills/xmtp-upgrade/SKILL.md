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
  version: 2.0.1
---

## CRITICAL CONSTRAINT — PROPOSE ONLY, NEVER EXECUTE

**You MUST NOT execute any CLI commands (forge, cast, yarn, source, git, etc.) yourself.**
Your job is to research the codebase, compose the correct commands, and present
them to the user as a numbered step-by-step plan. The user will copy and run
the commands themselves.

- **DO**: Read READMEs, config files, and `.env` to gather context.
- **DO**: Compose fully-substituted CLI commands with all flags and arguments.
- **DO**: Present commands in a numbered plan with explanations.
- **DO NOT**: Use the Bash tool to run any forge, cast, yarn, source, git, or shell commands.
- **DO NOT**: Parse command output — there will be no output since you are not running anything.

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

**Steps 1–5 are mandatory research steps. You MUST read these files before composing any commands.** The READMEs are the single source of truth for command syntax — do not rely on examples in this skill file or on prior knowledge. If the README commands differ from what you expect, follow the README.

1. Determine the **chain** from the contract name (settlement-chain or app-chain).

2. Determine the **signing mode**. Read the environment defaults table in the appropriate README:
   - Settlement chain: `script/upgrades/settlement-chain/README.md`
   - App chain: `script/upgrades/app-chain/README.md`

3. Read the appropriate workflow README (this is where you get the actual commands to propose):
   - Settlement chain + wallet: `script/upgrades/settlement-chain/README-wallet.md`
   - Settlement chain + fireblocks: `script/upgrades/settlement-chain/README-fireblocks.md`
   - App chain + wallet: `script/upgrades/app-chain/README-wallet.md`
   - App chain + fireblocks: `script/upgrades/app-chain/README-fireblocks.md`

4. Read `config/<environment>.json` to verify the required addresses exist (factory, parameterRegistryProxy, and the relevant contract proxy address).

5. Read `.env` and check whether the ADMIN address is uncommented in the block appropriate for the chosen signing method. If we are using signing method FIREBLOCKS then we expect ADMIN to be uncommented near the other FIREBLOCKS env vars, and commented out near the ADMIN_PRIVATE_KEY. If we are using signing method WALLET then it is vice-versa. This is because forge picks up the first ADMIN it finds when reading the .env file. If the `.env` is misconfigured, **tell the user what to change** — never edit `.env` yourself.

6. **Compose the plan.** Following the steps in the README exactly, substitute the correct contract upgrader script name and produce fully-formed commands. Present the plan as a numbered list of CLI steps:

   **Prerequisite steps** (always include at the top of the plan):
   - Repo cleanliness check: `forge clean && yarn prettier && yarn build && yarn test`, followed by `git status`. Note that the user must fix any failures or uncommitted changes before proceeding.
   - `source .env`
   - `export ENVIRONMENT=<env>`
   - `export ADMIN_ADDRESS_TYPE=<type>`
   - `.env` verification note (which ADMIN must be uncommented)

   **Upgrade steps** (from the README):
   - For each step, show the **complete command** in a fenced code block and a brief explanation of what it does.
   - Note any values the user must **capture from command output** and substitute into subsequent steps (e.g. `MIGRATOR_ADDRESS_FOR_STEP_2`, `FIREBLOCKS_NOTE_FOR_STEP_2`, `newImpl` addresses). Use clear placeholders like `<MIGRATOR_ADDRESS_FROM_STEP_N>` so the user knows what to substitute.
   - For **Fireblocks steps**: include a note after the relevant command reminding the user to approve the transaction in the Fireblocks console before proceeding to the next step.
   - For **app chain bridge steps**: include a verification step and note that bridge finalization may take a few minutes.

   **Post-upgrade steps** (always include at the end):
   - Note that the user should update `config/<environment>.json` with the new implementation address from the final step's output.
   - Include the verify-contract command from the Post-Upgrade section of the README.
   - If the user asks to skip the state check, note that they should add `export SKIP_STATE_CHECK=true` to the prerequisites.

7. Always include `--broadcast` in all transaction-submitting commands. Do not produce dry runs unless user specifically asks.

## Important rules

- **Never execute commands. Only propose them.**
- Never edit `.env` yourself — always tell the user what to change.
- Include `source .env` as a prerequisite step so that variables like `$ADMIN` are available for shell expansion.
- Include `export ENVIRONMENT=<env>` and `export ADMIN_ADDRESS_TYPE=<type>` as prerequisite steps.
- Use clear placeholders (e.g. `<MIGRATOR_ADDRESS_FROM_STEP_1>`) for values the user must capture from one step's output and use in a subsequent step.
- For Fireblocks: include `export FIREBLOCKS_NOTE="<description>"` as a step, with a human-readable description of the upgrade.

## Examples

Example 1: Upgrade with Fireblocks
User says: "upgrade NodeRegistry on testnet-dev using fireblocks"
Output: a numbered plan containing:
1. Repo cleanliness check commands
2. Prerequisite exports (`source .env`, `ENVIRONMENT`, `ADMIN_ADDRESS_TYPE`, `FIREBLOCKS_NOTE`)
3. `.env` verification note (Fireblocks ADMIN must be uncommented)
4. Step 1 command (deploy new implementation) with `--broadcast`

Example 2: Upgrade with wallet signing
User says: "upgrade the payer report manager on testnet-staging"
Output: a numbered plan containing:
1. Repo cleanliness check commands
2. Prerequisite exports
3. `.env` verification note
4. Step 1 command with `--broadcast`
5. Step 2 command with `--broadcast`, using placeholder `<MIGRATOR_ADDRESS_FROM_STEP_1>`
6. Post-upgrade: update `config/testnet-staging.json` with `<NEW_IMPL_ADDRESS>`
7. Verify-contract command

Example 3: App chain contract upgrade
User says: "upgrade GroupMessageBroadcaster on testnet-dev"
Output: a numbered plan containing:
1. Repo cleanliness check commands
2. Prerequisite exports
3. `.env` verification note
4. Upgrade steps including bridge command
5. Verification command (with note about bridge finalization delay)
6. Post-upgrade config update and verify-contract command

## Troubleshooting

Include these notes in the plan when relevant:

Error: Tests fail during repo cleanliness check
Cause: Existing test failures or code changes in the working tree
Solution: Fix failing tests or commit changes before retrying the upgrade

Error: `git status` shows uncommitted changes after prettier
Cause: Files were reformatted by prettier
Solution: Commit the formatting changes first

Error: Fireblocks transaction times out
Cause: Approver didn't act within the `--timeout` window (default 3600s)
Solution: Re-run the command — Fireblocks will create a new transaction for approval

Error: Wrong ADMIN address picked up by forge
Cause: `.env` has the wrong ADMIN uncommented for the chosen signing mode
Solution: Swap which ADMIN line is commented/uncommented in `.env`

Error: Bridge verification shows migrator hasn't arrived
Cause: Bridge finalization takes a few minutes
Solution: Wait 2-5 minutes and re-run the verification command
