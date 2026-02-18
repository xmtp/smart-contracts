// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { GroupMessageBroadcaster } from "../../../src/app-chain/GroupMessageBroadcaster.sol";
import { GroupMessageBroadcasterDeployer } from "../../deployers/GroupMessageBroadcasterDeployer.sol";
import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice Upgrades the GroupMessageBroadcaster proxy to a new implementation
 * @dev App chain upgrades are always 4 steps because they span two chains:
 *      1. Prepare - Deploy implementation and migrator on app chain
 *      2. SetMigrator - Set migrator in settlement chain parameter registry (ADMIN)
 *      3. BridgeParameter - Bridge migrator parameter to app chain (DEPLOYER)
 *      4. Upgrade - Execute migration on app chain (DEPLOYER)
 *
 *   Workflow 1 (Wallet):
 *     Steps 2-3 are combined into a single Bridge(address) command for convenience.
 *
 *   Workflow 2 (Fireblocks):
 *     Steps 2-3 must be run separately (step 2 via Fireblocks, step 3 without).
 *
 * Usage (Wallet):
 *   Step 1: ENVIRONMENT=testnet-dev forge script GroupMessageBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Steps 2-3: ENVIRONMENT=testnet-dev forge script GroupMessageBroadcasterUpgrader --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 4: ENVIRONMENT=testnet-dev forge script GroupMessageBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 *
 * Usage (Fireblocks):
 *   Step 1: ENVIRONMENT=testnet forge script GroupMessageBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Step 2: ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=FIREBLOCKS npx fireblocks-json-rpc --http -- forge script GroupMessageBroadcasterUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 14400 --retries 1 --sig "SetMigratorInParameterRegistry(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 3: ENVIRONMENT=testnet forge script GroupMessageBroadcasterUpgrader --rpc-url base_sepolia --slow --sig "BridgeParameter()" --broadcast
 *   Step 4: ENVIRONMENT=testnet forge script GroupMessageBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 */
contract GroupMessageBroadcasterUpgrader is BaseAppChainUpgrader {
    struct ContractState {
        address parameterRegistry;
        bool paused;
        uint32 minPayloadSize;
        uint32 maxPayloadSize;
        address payloadBootstrapper;
        string contractName;
        string version;
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.groupMessageBroadcasterProxy;
    }

    function _getContractName() internal pure override returns (string memory name_) {
        return "groupMessageBroadcaster";
    }

    function _getImplementationAddress(address proxy_) internal view override returns (address impl_) {
        return GroupMessageBroadcaster(proxy_).implementation();
    }

    function _deployOrGetImplementation(
        address factory_,
        address /* paramRegistry_ */,
        address proxy_
    ) internal override returns (address implementation_) {
        // Get parameter registry from proxy
        GroupMessageBroadcaster broadcaster = GroupMessageBroadcaster(proxy_);
        address parameterRegistry_ = broadcaster.parameterRegistry();

        // Compute implementation address
        address computedImpl = GroupMessageBroadcasterDeployer.getImplementation(factory_, parameterRegistry_);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(factory_, parameterRegistry_);
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getGroupMessageBroadcasterState(proxy_);
        return abi.encode(state);
    }

    function _getGroupMessageBroadcasterState(address proxy_) internal view returns (ContractState memory state_) {
        GroupMessageBroadcaster broadcaster = GroupMessageBroadcaster(proxy_);
        state_.parameterRegistry = broadcaster.parameterRegistry();
        state_.paused = broadcaster.paused();
        state_.minPayloadSize = broadcaster.minPayloadSize();
        state_.maxPayloadSize = broadcaster.maxPayloadSize();
        state_.payloadBootstrapper = broadcaster.payloadBootstrapper();

        // Try to get contractName and version, which may not exist in older implementations
        try broadcaster.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try broadcaster.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    function _isContractStateEqual(
        bytes memory stateBefore_,
        bytes memory stateAfter_
    ) internal pure override returns (bool isEqual_) {
        ContractState memory before = abi.decode(stateBefore_, (ContractState));
        ContractState memory afterState = abi.decode(stateAfter_, (ContractState));

        isEqual_ =
            before.parameterRegistry == afterState.parameterRegistry &&
            before.paused == afterState.paused &&
            before.minPayloadSize == afterState.minPayloadSize &&
            before.maxPayloadSize == afterState.maxPayloadSize &&
            before.payloadBootstrapper == afterState.payloadBootstrapper;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before.contractName)) == keccak256(bytes(afterState.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }

    function _logContractState(string memory title_, bytes memory state_) internal view override {
        ContractState memory state = abi.decode(state_, (ContractState));
        console.log("%s", title_);
        console.log("  Parameter registry: %s", state.parameterRegistry);
        console.log("  Paused: %s", state.paused);
        console.log("  Min payload size: %s", state.minPayloadSize);
        console.log("  Max payload size: %s", state.maxPayloadSize);
        console.log("  Payload bootstrapper: %s", state.payloadBootstrapper);
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getGroupMessageBroadcasterState(proxy_);
    }
}
