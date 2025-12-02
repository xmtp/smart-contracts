// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { AppChainParameterRegistry } from "../../../src/app-chain/AppChainParameterRegistry.sol";
import { AppChainParameterRegistryDeployer } from "../../deployers/AppChainParameterRegistryDeployer.sol";
import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice App Chain Parameter Registry upgrader
 * @dev This contract provides three entry points for the upgrade process:
 *      - Prepare(): Step 1 - Deploy implementation and migrator on app chain
 *      - Bridge(address): Step 2 - Bridge migrator parameter from settlement chain to app chain
 *      - Upgrade(): Step 3 - Execute migration and verify state preservation
 *
 * Usage:
 * NOTE: These steps execute on different chains, take care to get the --rpc-url correct for each step.
 *   Step 1: ENVIRONMENT=testnet-dev forge script AppChainParameterRegistryUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Step 2: ENVIRONMENT=testnet-dev forge script AppChainParameterRegistryUpgrader --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 3: ENVIRONMENT=testnet-dev forge script AppChainParameterRegistryUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
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
