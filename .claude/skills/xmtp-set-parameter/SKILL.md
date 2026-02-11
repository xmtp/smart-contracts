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
  version: 1.0.0
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

1. Determine the **signing mode**. Read the environment defaults table in the settlement chain README:
   - `script/parameters/settlement-chain/README.md`

2. Read the appropriate workflow README:
   - Wallet: `script/parameters/settlement-chain/README-wallet.md`
   - Fireblocks: `script/parameters/settlement-chain/README-fireblocks.md`
   - Bridging: `script/parameters/app-chain/README.md`

3. Read `config/<environment>.json` to verify `parameterRegistryProxy` exists. For bridge actions, also verify `gatewayProxy`, `feeTokenProxy`, `appChainId`, and `settlementChainId`.

4. Read `.env` and make sure the ADMIN address is uncommented in the block appropriate for the chosen signing method. If we are using signing method FIREBLOCKS then we expect ADMIN to be uncommented near the other FIREBLOCKS env vars, and commented out near the ADMIN_PRIVATE_KEY. If we are using signing method WALLET then it is vice-versa. This is because forge picks up the first ADMIN it finds when reading the .env file.

5. Execute the action by following the commands in the README exactly, substituting the parameter key, value, inferred value type signature (from the table above), and environment. For each command:
   - **Compose the full command** with all flags and arguments filled in.
   - **Show the command** to the user, explain what it does, and **run it in the same turn**. Do not ask for approval in chat — Claude Code's tool permission prompt already handles that.
   - For **reads**, use the "Reading Parameters" section of the relevant README. Parse and display the value in all formats (bytes32, uint256, address) from the output.
   - For **sets**, use the "Setting Parameters" section, choosing the correct value type subsection.
   - For **bridge**, follow `script/parameters/app-chain/README.md`.

6. For **Fireblocks** actions: after running the command, remind the user: "Please approve the transaction in the Fireblocks console. Let me know when it's confirmed." **Wait for the user to confirm** before proceeding.

7. For **bridge** actions: after bridging, offer to verify the parameter arrived on the app chain using the verification command in the bridging README. If the value shows as zero, remind the user that bridge finalization takes a few minutes and offer to re-check.

8. **After a successful set**, ask the user whether the parameter also needs to be bridged to the app chain. If yes, proceed with the bridge action.

## Important rules

- Never run a `--broadcast` command unless the user has asked for a broadcast (not a dry run). The tool permission prompt serves as the approval gate — do not also ask in chat.
- Never edit `.env` by yourself, always ask the user to do that.
- Source `.env` into the shell (`source .env`) before the first forge command so that variables like `$ADMIN` are available for shell expansion (e.g. in `--sender $ADMIN`). The `.env` file is a dotenv file that forge also reads internally, but command-line arguments require the shell to expand them first.
- Set `ENVIRONMENT` and `ADMIN_ADDRESS_TYPE` env vars before the first forge command.
- If any step fails, stop and discuss with the user before retrying or continuing.
- For reads, omit `--broadcast` and `--slow` — these are view-only calls.
- For Fireblocks: set `FIREBLOCKS_NOTE` to a human-readable description of the parameter change so the approver knows what they are signing.

## Examples

Example 1: Set and bridge a boolean parameter
User says: "use fireblocks to set a parameter claude.devops.test with value true in testnet-dev, then bridge it to the app chain"
Actions:
1. Read READMEs, config, and .env
2. Verify .env has Fireblocks ADMIN uncommented
3. Run `setBool` via Fireblocks JSON-RPC proxy with `--broadcast`
4. Wait for Fireblocks approval
5. Bridge parameter using `BridgeParameter` script
6. Verify parameter arrived on app chain

Example 2: Set a numeric parameter
User says: "set max nodes to 100 on testnet-dev"
Actions:
1. Infer key `xmtp.nodeRegistry.maxCanonicalNodes`, type uint256
2. Use wallet signing (testnet-dev default)
3. Run `setUint` with `--broadcast`

Example 3: Read a parameter
User says: "read the paused flag for the group message broadcaster on testnet"
Actions:
1. Infer key `xmtp.groupMessageBroadcaster.paused`
2. Run `get(string)` without `--broadcast` or `--slow`
3. Display value in all formats

## Troubleshooting

Error: Fireblocks transaction times out
Cause: Approver didn't act within the `--timeout` window (default 3600s)
Solution: Re-run the command — Fireblocks will create a new transaction for approval

Error: `forge script` fails with "sender not found" or wrong ADMIN
Cause: `.env` has the wrong ADMIN uncommented for the chosen signing mode
Solution: Ask the user to swap which ADMIN line is commented/uncommented in `.env`

Error: Bridge verification shows zero value
Cause: Bridge finalization takes a few minutes
Solution: Wait 2-5 minutes and re-run the verification command

Error: `forge script` compilation failure
Cause: Contract changes or missing dependencies
Solution: Run `forge build` first to diagnose, then fix before retrying

## Shared registry safety — paused flags

The parameter registry is a **singleton shared across all `testnet*` environments** (`testnet-dev`, `testnet-staging`, `testnet`). Any value set on the settlement chain is visible to all of them.

Setting a contract's `paused` flag (e.g. `xmtp.groupMessageBroadcaster.paused`) is **sensitive**. If the task requires setting a paused flag to `false`, do so on-chain, but **never commit `false` as the default value in the repository** (config files, scripts, etc.). Always leave paused flags defaulting to `true` in the repo. This prevents accidental unpausing in other environments if someone runs `update*()` functions without realizing the registry is shared.
