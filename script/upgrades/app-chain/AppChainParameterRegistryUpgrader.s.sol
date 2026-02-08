// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { AppChainParameterRegistry } from "../../../src/app-chain/AppChainParameterRegistry.sol";
import { AppChainParameterRegistryDeployer } from "../../deployers/AppChainParameterRegistryDeployer.sol";
import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice Upgrades the AppChainParameterRegistry proxy to a new implementation
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
 *   Step 1: ENVIRONMENT=testnet-dev forge script AppChainParameterRegistryUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Steps 2-3: ENVIRONMENT=testnet-dev forge script AppChainParameterRegistryUpgrader --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 4: ENVIRONMENT=testnet-dev forge script AppChainParameterRegistryUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 *
 * Usage (Fireblocks):
 *   Step 1: ENVIRONMENT=testnet forge script AppChainParameterRegistryUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Step 2: ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=FIREBLOCKS npx fireblocks-json-rpc --http -- forge script AppChainParameterRegistryUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 --sig "SetMigratorInParameterRegistry(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 3: ENVIRONMENT=testnet forge script AppChainParameterRegistryUpgrader --rpc-url base_sepolia --slow --sig "BridgeParameter()" --broadcast
 *   Step 4: ENVIRONMENT=testnet forge script AppChainParameterRegistryUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 */
contract AppChainParameterRegistryUpgrader is BaseAppChainUpgrader {
    struct ContractState {
        string contractName;
        string version;
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.parameterRegistryProxy;
    }

    function _getContractName() internal pure override returns (string memory name_) {
        return "appChainParameterRegistry";
    }

    function _getImplementationAddress(address proxy_) internal view override returns (address impl_) {
        return AppChainParameterRegistry(proxy_).implementation();
    }

    function _deployOrGetImplementation(
        address factory_,
        address /* paramRegistry_ */,
        address /* proxy_ */
    ) internal override returns (address implementation_) {
        // Compute implementation address
        address computedImpl = AppChainParameterRegistryDeployer.getImplementation(factory_);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(factory_);
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getAppChainParameterRegistryState(proxy_);
        return abi.encode(state);
    }

    function _getAppChainParameterRegistryState(address proxy_) internal view returns (ContractState memory state_) {
        AppChainParameterRegistry registry = AppChainParameterRegistry(proxy_);

        // Try to get contractName and version, which may not exist in older implementations
        try registry.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try registry.version() returns (string memory version_) {
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

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before.contractName).length > 0) {
            isEqual_ = keccak256(bytes(before.contractName)) == keccak256(bytes(afterState.contractName));
        } else {
            // If before state had no contractName, we don't require it in after state
            isEqual_ = true;
        }
        // Note: version is intentionally not checked, it can change
    }

    function _logContractState(string memory title_, bytes memory state_) internal view override {
        ContractState memory state = abi.decode(state_, (ContractState));
        console.log("%s", title_);
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getAppChainParameterRegistryState(proxy_);
    }
}
