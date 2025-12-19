// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { SettlementChainParameterRegistry } from "../../../src/settlement-chain/SettlementChainParameterRegistry.sol";
import { BaseSettlementChainUpgrader } from "./BaseSettlementChainUpgrader.s.sol";
import { SettlementChainParameterRegistryDeployer } from "../../deployers/SettlementChainParameterRegistryDeployer.sol";

/**
 * @notice Upgrades the SettlementChainParameterRegistry proxy to a new implementation
 * @dev This script provides two upgrade paths:
 *
 *   Path 1 (All-in-one, for non-Fireblocks environments):
 *     - Upgrade(): Performs all steps in a single transaction batch
 *
 *   Path 2 (Three-step, for Fireblocks environments):
 *     - DeployImplementationAndMigrator(): Step 1 - Deploy implementation and migrator (non-Fireblocks)
 *     - SetMigratorInParameterRegistry(address): Step 2 - Set migrator in parameter registry (Fireblocks)
 *     - PerformMigration(): Step 3 - Execute migration and verify state (non-Fireblocks)
 *
 * Usage (non-Fireblocks):
 *   ENVIRONMENT=testnet-dev forge script SettlementChainParameterRegistryUpgrader --rpc-url base_sepolia --slow --sig "Upgrade()" --broadcast
 *
 * Usage (Fireblocks):
 *   Step 1: ENVIRONMENT=testnet-dev forge script SettlementChainParameterRegistryUpgrader --rpc-url base_sepolia --slow --sig "DeployImplementationAndMigrator()" --broadcast
 *   Step 2: ENVIRONMENT=testnet-dev ADMIN_ADDRESS_TYPE=FIREBLOCKS npx fireblocks-json-rpc --http -- forge script SettlementChainParameterRegistryUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --sig "SetMigratorInParameterRegistry(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 3: ENVIRONMENT=testnet-dev forge script SettlementChainParameterRegistryUpgrader --rpc-url base_sepolia --slow --sig "PerformMigration()" --broadcast
 *
 */
contract SettlementChainParameterRegistryUpgrader is BaseSettlementChainUpgrader {
    struct ContractState {
        string contractName;
        string version;
    }

    // The all-in-one function (Upgrade) and three-step functions (DeployImplementationAndMigrator,
    // SetMigratorInParameterRegistry, PerformMigration) are inherited from BaseSettlementChainUpgrader
    // and can be called directly via forge script --sig

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.parameterRegistryProxy;
    }

    function _deployOrGetImplementation() internal override returns (address implementation_) {
        address factory = _deployment.factory;

        // Compute implementation address
        address computedImpl = SettlementChainParameterRegistryDeployer.getImplementation(factory);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(factory);
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return IParameterRegistry(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getSettlementChainParameterRegistryState(proxy_);
        return abi.encode(state);
    }

    function _isContractStateEqual(
        bytes memory stateBefore_,
        bytes memory stateAfter_
    ) internal pure override returns (bool isEqual_) {
        ContractState memory before = abi.decode(stateBefore_, (ContractState));
        ContractState memory afterState = abi.decode(stateAfter_, (ContractState));

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        isEqual_ = true;
        if (bytes(before.contractName).length > 0) {
            isEqual_ = keccak256(bytes(before.contractName)) == keccak256(bytes(afterState.contractName));
        }
        // Note: version is intentionally not checked, it can change
        return isEqual_;
    }

    function _logContractState(string memory title_, bytes memory state_) internal view override {
        ContractState memory state = abi.decode(state_, (ContractState));
        console.log("%s", title_);
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getSettlementChainParameterRegistryState(
        address proxy_
    ) internal view returns (ContractState memory state_) {
        SettlementChainParameterRegistry paramRegistry = SettlementChainParameterRegistry(proxy_);

        // Try to get contractName and version, which may not exist in older implementations
        try paramRegistry.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try paramRegistry.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getSettlementChainParameterRegistryState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        isEqual_ = true;
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
        return isEqual_;
    }
}
