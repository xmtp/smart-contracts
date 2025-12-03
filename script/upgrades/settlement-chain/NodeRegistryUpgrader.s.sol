// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { NodeRegistry } from "../../../src/settlement-chain/NodeRegistry.sol";
import { BaseSettlementChainUpgrader } from "./BaseSettlementChainUpgrader.s.sol";
import { NodeRegistryDeployer } from "../../deployers/NodeRegistryDeployer.sol";

/**
 * @notice Upgrades the NodeRegistry proxy to a new implementation
 * @dev This script:
 *      - Reads addresses for: factory, parameter registry and node registry proxy from config JSON file
 *      - Deploys a new NodeRegistry implementation via the Factory (no-ops if it exists)
 *      - Creates a GenericEIP1967Migrator with the new implementation
 *      - Sets the migrator address in the Parameter Registry
 *      - Executes the migration on the proxy
 *      - Compares the state before and after upgrade
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script NodeRegistryUpgrader --rpc-url base_sepolia --slow --sig "UpgradeNodeRegistry()" --broadcast
 *
 */
contract NodeRegistryUpgrader is BaseSettlementChainUpgrader {
    struct ContractState {
        address parameterRegistry;
        uint8 canonicalNodesCount;
        uint32 nodeCount;
        uint32[] canonicalNodes;
        bool hasGetCanonicalNodesFunction;
        string contractName;
        string version;
    }

    function UpgradeNodeRegistry() external {
        _upgrade();
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.nodeRegistryProxy;
    }

    function _deployOrGetImplementation() internal override returns (address implementation_) {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;

        // Compute implementation address
        address computedImpl = NodeRegistryDeployer.getImplementation(factory, paramRegistry);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = NodeRegistryDeployer.deployImplementation(factory, paramRegistry);
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return NodeRegistry(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getNodeRegistryState(proxy_);
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
            before.canonicalNodesCount == afterState.canonicalNodesCount &&
            before.nodeCount == afterState.nodeCount;

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
        console.log("  Canonical nodes count: %s", uint256(state.canonicalNodesCount));
        console.log("  Node count: %s", uint256(state.nodeCount));

        if (state.hasGetCanonicalNodesFunction) {
            console.log("  Canonical nodes array length: %s", state.canonicalNodes.length);
            if (state.canonicalNodes.length == 0 && state.nodeCount > 0) {
                console.log("  WARNING: Canonical nodes array is empty but node count is %s", uint256(state.nodeCount));
            }
        }

        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getNodeRegistryState(address proxy_) internal view returns (ContractState memory state_) {
        NodeRegistry nodeRegistry = NodeRegistry(proxy_);
        state_.parameterRegistry = nodeRegistry.parameterRegistry();
        state_.canonicalNodesCount = nodeRegistry.canonicalNodesCount();
        state_.nodeCount = nodeRegistry.getAllNodesCount();

        // Try to get canonical nodes array, which may not exist in older implementations
        try nodeRegistry.getCanonicalNodes() returns (uint32[] memory canonicalNodes_) {
            state_.canonicalNodes = canonicalNodes_;
            state_.hasGetCanonicalNodesFunction = true;
        } catch {
            state_.canonicalNodes = new uint32[](0);
            state_.hasGetCanonicalNodesFunction = false;
        }

        // Try to get contractName and version, which may not exist in older implementations
        try nodeRegistry.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try nodeRegistry.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getNodeRegistryState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == afterState_.parameterRegistry &&
            before_.canonicalNodesCount == afterState_.canonicalNodesCount &&
            before_.nodeCount == afterState_.nodeCount;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }
}
