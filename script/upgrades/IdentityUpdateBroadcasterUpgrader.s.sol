// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Script.sol";
import { IdentityUpdateBroadcaster } from "../../src/app-chain/IdentityUpdateBroadcaster.sol";
import { BaseUpgrader } from "./BaseUpgrader.s.sol";
import { IdentityUpdateBroadcasterDeployer } from "../deployers/IdentityUpdateBroadcasterDeployer.sol";

/**
 * @notice Upgrades the IdentityUpdateBroadcaster proxy to a new implementation
 * @dev This script:
 *      - Reads addresses for: factory, parameter registry and identity update broadcaster proxy from config JSON file
 *      - Deploys a new IdentityUpdateBroadcaster implementation via the Factory (no-ops if it exists)
 *      - Creates a GenericEIP1967Migrator with the new implementation
 *      - Sets the migrator address in the Parameter Registry
 *      - Executes the migration on the proxy
 *      - Compares the state before and after upgrade
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script script/upgrades/IdentityUpdateBroadcasterUpgrader.s.sol:IdentityUpdateBroadcasterUpgrader --rpc-url xmtp_ropsten --slow --sig "UpgradeIdentityUpdateBroadcaster()" --broadcast
 *
 */
contract IdentityUpdateBroadcasterUpgrader is BaseUpgrader {
    struct ContractState {
        address parameterRegistry;
        uint32 minPayloadSize;
        uint32 maxPayloadSize;
        bool paused;
        address payloadBootstrapper;
        string contractName;
        string version;
    }

    function UpgradeIdentityUpdateBroadcaster() external {
        _upgrade();
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.identityUpdateBroadcasterProxy;
    }

    function _deployOrGetImplementation() internal override returns (address implementation_) {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;

        // Compute implementation address
        address computedImpl = IdentityUpdateBroadcasterDeployer.getImplementation(factory, paramRegistry);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(factory, paramRegistry);
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return IdentityUpdateBroadcaster(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getIdentityUpdateBroadcasterState(proxy_);
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
            before.minPayloadSize == afterState.minPayloadSize &&
            before.maxPayloadSize == afterState.maxPayloadSize &&
            before.paused == afterState.paused &&
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
        console.log("  Min payload size: %s", uint256(state.minPayloadSize));
        console.log("  Max payload size: %s", uint256(state.maxPayloadSize));
        console.log("  Paused: %s", state.paused);
        console.log("  Payload bootstrapper: %s", state.payloadBootstrapper);
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getIdentityUpdateBroadcasterState(address proxy_) internal view returns (ContractState memory state_) {
        IdentityUpdateBroadcaster identityUpdateBroadcaster = IdentityUpdateBroadcaster(proxy_);
        state_.parameterRegistry = identityUpdateBroadcaster.parameterRegistry();
        state_.minPayloadSize = identityUpdateBroadcaster.minPayloadSize();
        state_.maxPayloadSize = identityUpdateBroadcaster.maxPayloadSize();
        state_.paused = identityUpdateBroadcaster.paused();
        state_.payloadBootstrapper = identityUpdateBroadcaster.payloadBootstrapper();

        // Try to get contractName and version, which may not exist in older implementations
        try identityUpdateBroadcaster.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try identityUpdateBroadcaster.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getIdentityUpdateBroadcasterState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == afterState_.parameterRegistry &&
            before_.minPayloadSize == afterState_.minPayloadSize &&
            before_.maxPayloadSize == afterState_.maxPayloadSize &&
            before_.paused == afterState_.paused &&
            before_.payloadBootstrapper == afterState_.payloadBootstrapper;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }
}
