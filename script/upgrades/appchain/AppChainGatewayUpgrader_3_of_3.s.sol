// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AppChainGateway } from "../../../src/app-chain/AppChainGateway.sol";
import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice Step 3 of 3: Perform the upgrade on the app chain
 * @dev This script:
 *      - Captures contract state before upgrade
 *      - Executes the migration
 *      - Compares state before and after upgrade
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader_3_of_3 --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 */
contract AppChainGatewayUpgrader_3_of_3 is BaseAppChainUpgrader {
    struct ContractState {
        address parameterRegistry;
        address settlementChainGateway;
        address settlementChainGatewayAlias;
        bool paused;
        string contractName;
        string version;
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.gatewayProxy;
    }

    function _getContractName() internal pure override returns (string memory name_) {
        return "appChainGateway";
    }

    function _getImplementationAddress(address proxy_) internal view override returns (address impl_) {
        return AppChainGateway(proxy_).implementation();
    }

    function _deployOrGetImplementation(
        address,
        address,
        address
    ) internal pure override returns (address) {
        revert("Not used in step 3");
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getAppChainGatewayState(proxy_);
        return abi.encode(state);
    }

    function _getAppChainGatewayState(address proxy_) internal view returns (ContractState memory state_) {
        AppChainGateway gateway = AppChainGateway(proxy_);
        state_.parameterRegistry = gateway.parameterRegistry();
        state_.settlementChainGateway = gateway.settlementChainGateway();
        state_.settlementChainGatewayAlias = gateway.settlementChainGatewayAlias();
        state_.paused = gateway.paused();

        // Try to get contractName and version, which may not exist in older implementations
        try gateway.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try gateway.version() returns (string memory version_) {
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
            before.settlementChainGateway == afterState.settlementChainGateway &&
            before.settlementChainGatewayAlias == afterState.settlementChainGatewayAlias &&
            before.paused == afterState.paused;

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
        console.log("  Settlement chain gateway: %s", state.settlementChainGateway);
        console.log("  Settlement chain gateway alias: %s", state.settlementChainGatewayAlias);
        console.log("  Paused: %s", state.paused);
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }
}
