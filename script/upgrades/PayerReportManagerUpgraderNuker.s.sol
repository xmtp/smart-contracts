// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Script.sol";
import { PayerReportManager } from "../../src/settlement-chain/PayerReportManager.sol";
import { BaseUpgraderNuker } from "./BaseUpgraderNuker.s.sol";
import { PayerReportManagerDeployer } from "../deployers/PayerReportManagerDeployer.sol";

/**
 * @notice Upgrades the PayerReportManager proxy to a new implementation
 * @dev This script:
 *      - Reads addresses for: factory, parameter registry, node registry, payer registry and payer report manager proxy from config JSON file
 *      - Deploys a new PayerReportManager implementation via the Factory (no-ops if it exists)
 *      - Creates a GenericEIP1967Migrator with the new implementation
 *      - Sets the migrator address in the Parameter Registry
 *      - Executes the migration on the proxy
 *      - Compares the state before and after upgrade
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script script/upgrades/PayerReportManagerUpgraderNuker.s.sol:PayerReportManagerUpgrader --rpc-url base_sepolia --slow --sig "UpgradePayerReportManager()" --broadcast
 *
 */
contract PayerReportManagerUpgraderNuker is BaseUpgraderNuker {
    struct ContractState {
        address parameterRegistry;
        address nodeRegistry;
        address payerRegistry;
        uint16 protocolFeeRate;
        string contractName;
        string version;
    }

    function UpgradePayerReportManager() external {
        _upgrade();
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.payerReportManagerProxy;
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return PayerReportManager(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getPayerReportManagerState(proxy_);
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
            before.nodeRegistry == afterState.nodeRegistry &&
            before.payerRegistry == afterState.payerRegistry &&
            before.protocolFeeRate == afterState.protocolFeeRate;

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
        console.log("  Node registry: %s", state.nodeRegistry);
        console.log("  Payer registry: %s", state.payerRegistry);
        console.log("  Protocol fee rate: %s", uint256(state.protocolFeeRate));
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getPayerReportManagerState(address proxy_) internal view returns (ContractState memory state_) {
        PayerReportManager payerReportManager = PayerReportManager(proxy_);
        state_.parameterRegistry = payerReportManager.parameterRegistry();
        state_.nodeRegistry = payerReportManager.nodeRegistry();
        state_.payerRegistry = payerReportManager.payerRegistry();
        state_.protocolFeeRate = payerReportManager.protocolFeeRate();

        // Try to get contractName and version, which may not exist in older implementations
        try payerReportManager.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try payerReportManager.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getPayerReportManagerState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == afterState_.parameterRegistry &&
            before_.nodeRegistry == afterState_.nodeRegistry &&
            before_.payerRegistry == afterState_.payerRegistry &&
            before_.protocolFeeRate == afterState_.protocolFeeRate;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }
}
