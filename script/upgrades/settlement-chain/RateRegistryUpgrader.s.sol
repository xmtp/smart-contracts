// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { RateRegistry } from "../../../src/settlement-chain/RateRegistry.sol";
import { BaseSettlementChainUpgrader } from "./BaseSettlementChainUpgrader.s.sol";
import { RateRegistryDeployer } from "../../deployers/RateRegistryDeployer.sol";

/**
 * @notice Upgrades the RateRegistry proxy to a new implementation
 * @dev This script:
 *      - Reads addresses for: factory, parameter registry and rate registry proxy from config JSON file
 *      - Deploys a new RateRegistry implementation via the Factory (no-ops if it exists)
 *      - Creates a GenericEIP1967Migrator with the new implementation
 *      - Sets the migrator address in the Parameter Registry
 *      - Executes the migration on the proxy
 *      - Compares the state before and after upgrade
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script RateRegistryUpgrader --rpc-url base_sepolia --slow --sig "UpgradeRateRegistry()" --broadcast
 *
 */
contract RateRegistryUpgrader is BaseSettlementChainUpgrader {
    struct ContractState {
        address parameterRegistry;
        uint256 ratesCount;
        string contractName;
        string version;
    }

    function UpgradeRateRegistry() external {
        _upgrade();
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.rateRegistryProxy;
    }

    function _deployOrGetImplementation() internal override returns (address implementation_) {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;

        // Compute implementation address
        address computedImpl = RateRegistryDeployer.getImplementation(factory, paramRegistry);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = RateRegistryDeployer.deployImplementation(factory, paramRegistry);
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return RateRegistry(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getRateRegistryState(proxy_);
        return abi.encode(state);
    }

    function _isContractStateEqual(
        bytes memory stateBefore_,
        bytes memory stateAfter_
    ) internal pure override returns (bool isEqual_) {
        ContractState memory before = abi.decode(stateBefore_, (ContractState));
        ContractState memory afterState = abi.decode(stateAfter_, (ContractState));

        isEqual_ =
            before.parameterRegistry == afterState.parameterRegistry &&
            before.ratesCount == afterState.ratesCount;

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
        console.log("  Rates count: %s", state.ratesCount);
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getRateRegistryState(address proxy_) internal view returns (ContractState memory state_) {
        RateRegistry rateRegistry = RateRegistry(proxy_);
        state_.parameterRegistry = rateRegistry.parameterRegistry();
        state_.ratesCount = rateRegistry.getRatesCount();

        // Try to get contractName and version, which may not exist in older implementations
        try rateRegistry.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try rateRegistry.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getRateRegistryState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == afterState_.parameterRegistry &&
            before_.ratesCount == afterState_.ratesCount;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }
}
