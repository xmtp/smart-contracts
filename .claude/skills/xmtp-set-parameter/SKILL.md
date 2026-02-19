---
name: xmtp-set-parameter
description: >
  Set, read, or bridge a parameter in the XMTP protocol parameter registry,
  supporting both wallet and Fireblocks signing modes. Use when user asks to
  "set a parameter", "read a parameter", "check a parameter value",
  "bridge a parameter to the app chain", or mentions the parameter registry,
  paused flags, or specific keys like nodeRegistry, payerRegistry, rateRegistry.
argument-hint: [action] [key] [value] [environment] [signing-mode]
metadata:
  author: XMTP
  version: 2.0.0
---

## CRITICAL CONSTRAINT — PROPOSE ONLY, NEVER EXECUTE

**You MUST NOT execute any CLI commands (forge, cast, source, etc.) yourself.**
Your job is to research the codebase, compose the correct commands, and present
them to the user as a numbered step-by-step plan. The user will copy and run
the commands themselves.

- **DO**: Read READMEs, config files, and `.env` to gather context.
- **DO**: Compose fully-substituted CLI commands with all flags and arguments.
- **DO**: Present commands in a numbered plan with explanations.
- **DO NOT**: Use the Bash tool to run any forge, cast, source, or shell commands.
- **DO NOT**: Parse command output — there will be no output since you are not running anything.

---

The user wants to set, read, or bridge a parameter. Parse from their request:

- **Action**: set, read, or bridge (default: set)
- **Parameter key**: the registry key (e.g. `xmtp.nodeRegistry.maxCanonicalNodes`)
- **Value**: the value to set (not needed for read or bridge)
- **Value type** (for set): infer from the value — address (0x… 40 hex chars), bool (true/false), uint256 (plain number), or bytes32 (0x… 64 hex chars). If ambiguous, ask the user.
- **Environment**: testnet-dev, testnet-staging, testnet, or mainnet
- **Signing mode** (optional): wallet or fireblocks. If not specified, use the environment default from the README.

Accept fuzzy descriptions from the user (e.g. "set max nodes to 100 on testnet-dev", "pause the group message broadcaster on testnet", "read the paused flag on the app chain").

## Value type mapping

| Inferred type | Solidity signature             | Example value                                                        |
| ------------- | ------------------------------ | -------------------------------------------------------------------- |
| address       | `setAddress(string,address)`   | `0x1234567890123456789012345678901234567890`                         |
| bool          | `setBool(string,bool)`         | `true` or `false`                                                    |
| uint256       | `setUint(string,uint256)`      | `100`                                                                |
| bytes32       | `set(string,bytes32)`          | `0x0000000000000000000000000000000000000000000000000000000000000001` |

## Procedure

**Steps 1–4 are mandatory research steps. You MUST read these files before composing any commands.** The READMEs are the single source of truth for command syntax — do not rely on examples in this skill file or on prior knowledge. If the README commands differ from what you expect, follow the README.

1. Determine the **signing mode**. Read the environment defaults table in the settlement chain README:
   - `script/parameters/settlement-chain/README.md`

2. Read the appropriate workflow README (this is where you get the actual commands to propose):
   - Wallet: `script/parameters/settlement-chain/README-wallet.md`
   - Fireblocks: `script/parameters/settlement-chain/README-fireblocks.md`
   - Bridging: `script/parameters/app-chain/README.md`

3. Read `config/<environment>.json` to verify `parameterRegistryProxy` exists. For bridge actions, also verify `gatewayProxy`, `feeTokenProxy`, `appChainId`, and `settlementChainId`.

4. Read `.env` and check whether the ADMIN address is uncommented in the block appropriate for the chosen signing method. If we are using signing method FIREBLOCKS then we expect ADMIN to be uncommented near the other FIREBLOCKS env vars, and commented out near the ADMIN_PRIVATE_KEY. If we are using signing method WALLET then it is vice-versa. This is because forge picks up the first ADMIN it finds when reading the .env file. If the `.env` is misconfigured, **tell the user what to change** — never edit `.env` yourself.

5. **Compose the plan.** Following the commands in the README exactly, substitute the parameter key, value, inferred value type signature (from the table above), and environment to produce fully-formed commands. Present the plan as a numbered list of CLI steps:
   - For each step, show the **complete command** in a fenced code block and a brief explanation of what it does.
   - For **reads**, use the "Reading Parameters" section of the relevant README. Note that the user should look for bytes32, uint256, and address formats in the output.
   - For **sets**, use the "Setting Parameters" section, choosing the correct value type subsection.
   - For **bridge**, follow `script/parameters/app-chain/README.md`.
   - Include prerequisite shell commands (e.g. `source .env`, `export ENVIRONMENT=...`, `export ADMIN_ADDRESS_TYPE=...`) as the first steps in the plan.

6. For **Fireblocks** actions: include a note after the relevant command step reminding the user to approve the transaction in the Fireblocks console before proceeding to the next step.

7. For **bridge** actions: include a verification step at the end using the verification command from the bridging README. Note that if the value shows as zero, bridge finalization may take a few minutes.

8. **After a set plan**, note that the parameter may also need to be bridged to the app chain, and offer to compose the bridge plan if the user wants it.

## Important rules

- **Never execute commands. Only propose them.**
- Never edit `.env` yourself — always tell the user what to change.
- Include `source .env` as a prerequisite step so that variables like `$ADMIN` are available for shell expansion.
- Include `export ENVIRONMENT=<env>` and `export ADMIN_ADDRESS_TYPE=<type>` as prerequisite steps.
- For reads, note that `--broadcast` and `--slow` should be omitted — these are view-only calls.
- For Fireblocks: include `export FIREBLOCKS_NOTE="<description>"` as a step, with a human-readable description of the parameter change.
- If the user did not specify `--broadcast`, compose the commands as dry runs (without `--broadcast`). Note this in the plan.

## Examples

Example 1: Set and bridge a boolean parameter
User says: "use fireblocks to set a parameter claude.devops.test with value true in testnet-dev, then bridge it to the app chain"
Output: a numbered plan containing:
1. Prerequisite exports (`source .env`, `ENVIRONMENT`, `ADMIN_ADDRESS_TYPE`, `FIREBLOCKS_NOTE`)
2. `.env` verification note (Fireblocks ADMIN must be uncommented)
3. `setBool` command via Fireblocks JSON-RPC proxy with `--broadcast`
4. Note: approve in Fireblocks console before continuing
5. Bridge command using `BridgeParameter` script
6. Verification command for app chain

Example 2: Set a numeric parameter
User says: "set max nodes to 100 on testnet-dev"
Output: a numbered plan containing:
1. Prerequisite exports
2. `.env` verification note
3. `setUint` command with `--broadcast`

Example 3: Read a parameter
User says: "read the paused flag for the group message broadcaster on testnet"
Output: a numbered plan containing:
1. Prerequisite exports
2. `get(string)` command without `--broadcast` or `--slow`
3. Note: look for bytes32, uint256, and address values in output

## Troubleshooting

Include these notes in the plan when relevant:

Error: Fireblocks transaction times out
Cause: Approver didn't act within the `--timeout` window (default 3600s)
Solution: Re-run the command — Fireblocks will create a new transaction for approval

Error: `forge script` fails with "sender not found" or wrong ADMIN
Cause: `.env` has the wrong ADMIN uncommented for the chosen signing mode
Solution: Swap which ADMIN line is commented/uncommented in `.env`

Error: Bridge verification shows zero value
Cause: Bridge finalization takes a few minutes
Solution: Wait 2-5 minutes and re-run the verification command

Error: `forge script` compilation failure
Cause: Contract changes or missing dependencies
Solution: Run `forge build` first to diagnose, then fix before retrying

## Shared registry safety — paused flags

The parameter registry is a **singleton shared across all `testnet*` environments** (`testnet-dev`, `testnet-staging`, `testnet`). Any value set on the settlement chain is visible to all of them.

Setting a contract's `paused` flag (e.g. `xmtp.groupMessageBroadcaster.paused`) is **sensitive**. If the task requires setting a paused flag to `false`, include a warning in the plan. Also note: **never commit `false` as the default value in the repository** (config files, scripts, etc.). Always leave paused flags defaulting to `true` in the repo. This prevents accidental unpausing in other environments if someone runs `update*()` functions without realizing the registry is shared.
