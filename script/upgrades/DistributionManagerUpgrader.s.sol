// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Script.sol";
import { DistributionManager } from "../../src/settlement-chain/DistributionManager.sol";
import { BaseUpgrader } from "./BaseUpgrader.s.sol";
import { DistributionManagerDeployer } from "../deployers/DistributionManagerDeployer.sol";

/**
 * @notice Upgrades the DistributionManager proxy to a new implementation
 * @dev This script:
 *      - Reads addresses for: factory, parameter registry, node registry, payer report manager, payer registry, fee token and distribution manager proxy from config JSON file
 *      - Deploys a new DistributionManager implementation via the Factory (no-ops if it exists)
 *      - Creates a GenericEIP1967Migrator with the new implementation
 *      - Sets the migrator address in the Parameter Registry
 *      - Executes the migration on the proxy
 *      - Compares the state before and after upgrade
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script script/upgrades/DistributionManagerUpgrader.s.sol:DistributionManagerUpgrader --rpc-url base_sepolia --slow --sig "UpgradeDistributionManager()" --broadcast
 *
 */
contract DistributionManagerUpgrader is BaseUpgrader {
    struct ContractState {
        address parameterRegistry;
        address nodeRegistry;
        address payerReportManager;
        address payerRegistry;
        address feeToken;
        address protocolFeesRecipient;
        bool paused;
        uint96 owedProtocolFees;
        uint96 totalOwedFees;
        string contractName;
        string version;
    }

    function UpgradeDistributionManager() external {
        _upgrade();
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.distributionManagerProxy;
    }

    function _deployOrGetImplementation() internal override returns (address implementation_) {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address nodeRegistry = _deployment.nodeRegistryProxy;
        address payerReportManager = _deployment.payerReportManagerProxy;
        address payerRegistry = _deployment.payerRegistryProxy;
        address feeToken = _deployment.feeTokenProxy;

        // Compute implementation address
        address computedImpl = DistributionManagerDeployer.getImplementation(
            factory,
            paramRegistry,
            nodeRegistry,
            payerReportManager,
            payerRegistry,
            feeToken
        );

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            factory,
            paramRegistry,
            nodeRegistry,
            payerReportManager,
            payerRegistry,
            feeToken
        );
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return DistributionManager(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getDistributionManagerState(proxy_);
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
            before.payerReportManager == afterState.payerReportManager &&
            before.payerRegistry == afterState.payerRegistry &&
            before.feeToken == afterState.feeToken &&
            before.protocolFeesRecipient == afterState.protocolFeesRecipient &&
            before.paused == afterState.paused &&
            before.owedProtocolFees == afterState.owedProtocolFees &&
            before.totalOwedFees == afterState.totalOwedFees;

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
        console.log("  Payer report manager: %s", state.payerReportManager);
        console.log("  Payer registry: %s", state.payerRegistry);
        console.log("  Fee token: %s", state.feeToken);
        console.log("  Protocol fees recipient: %s", state.protocolFeesRecipient);
        console.log("  Paused: %s", state.paused);
        console.log("  Owed protocol fees: %s", uint256(state.owedProtocolFees));
        console.log("  Total owed fees: %s", uint256(state.totalOwedFees));
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getDistributionManagerState(address proxy_) internal view returns (ContractState memory state_) {
        DistributionManager distributionManager = DistributionManager(proxy_);
        state_.parameterRegistry = distributionManager.parameterRegistry();
        state_.nodeRegistry = distributionManager.nodeRegistry();
        state_.payerReportManager = distributionManager.payerReportManager();
        state_.payerRegistry = distributionManager.payerRegistry();
        state_.feeToken = distributionManager.feeToken();
        state_.protocolFeesRecipient = distributionManager.protocolFeesRecipient();
        state_.paused = distributionManager.paused();
        state_.owedProtocolFees = distributionManager.owedProtocolFees();
        state_.totalOwedFees = distributionManager.totalOwedFees();

        // Try to get contractName and version, which may not exist in older implementations
        try distributionManager.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try distributionManager.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getDistributionManagerState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == afterState_.parameterRegistry &&
            before_.nodeRegistry == afterState_.nodeRegistry &&
            before_.payerReportManager == afterState_.payerReportManager &&
            before_.payerRegistry == afterState_.payerRegistry &&
            before_.feeToken == afterState_.feeToken &&
            before_.protocolFeesRecipient == afterState_.protocolFeesRecipient &&
            before_.paused == afterState_.paused &&
            before_.owedProtocolFees == afterState_.owedProtocolFees &&
            before_.totalOwedFees == afterState_.totalOwedFees;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }
}
