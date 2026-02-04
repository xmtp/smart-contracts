// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/Script.sol";
import { AppChainGateway } from "../../../src/app-chain/AppChainGateway.sol";
import { AppChainGatewayDeployer } from "../../deployers/AppChainGatewayDeployer.sol";
import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice Upgrades the AppChainGateway proxy to a new implementation
 * @dev This script provides two upgrade workflows. Both are three steps because they span two chains.
 *
 *   Workflow 1 (Wallet, for non-Fireblocks environments):
 *     - Step 1: Prepare() on app chain (DEPLOYER)
 *     - Step 2: Bridge(address) on settlement chain (ADMIN via private key, DEPLOYER for bridging)
 *     - Step 3: Upgrade() on app chain (DEPLOYER)
 *
 *   Workflow 2 (Fireblocks, for testnet/mainnet):
 *     - Step 1: Prepare() on app chain (DEPLOYER)
 *     - Step 2: Bridge(address) on settlement chain (ADMIN via Fireblocks, DEPLOYER for bridging)
 *     - Step 3: Upgrade() on app chain (DEPLOYER)
 *
 * Usage (Wallet):
 *   Step 1: ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Step 2: ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 3: ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 *
 * Usage (Fireblocks):
 *   Step 1: ENVIRONMENT=testnet forge script AppChainGatewayUpgrader --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 *   Step 2: ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=FIREBLOCKS npx fireblocks-json-rpc --http -- forge script AppChainGatewayUpgrader --sender $ADMIN --slow --unlocked --rpc-url {} --timeout 3600 --retries 1 --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
 *   Step 3: ENVIRONMENT=testnet forge script AppChainGatewayUpgrader --rpc-url xmtp_ropsten --slow --sig "Upgrade()" --broadcast
 */
contract AppChainGatewayUpgrader is BaseAppChainUpgrader {
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
        address factory_,
        address paramRegistry_,
        address proxy_
    ) internal override returns (address implementation_) {
        // Get settlement chain gateway from proxy
        AppChainGateway gateway = AppChainGateway(proxy_);
        address settlementChainGateway_ = gateway.settlementChainGateway();

        // Compute implementation address
        address computedImpl = AppChainGatewayDeployer.getImplementation(
            factory_,
            paramRegistry_,
            settlementChainGateway_
        );

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
            factory_,
            paramRegistry_,
            settlementChainGateway_
        );
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

    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getAppChainGatewayState(proxy_);
    }
}
