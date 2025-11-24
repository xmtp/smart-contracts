// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { AppChainGateway } from "../../../src/app-chain/AppChainGateway.sol";
import { IMigratable } from "../../../src/abstract/interfaces/IMigratable.sol";
import { Utils } from "../../utils/Utils.sol";

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
contract AppChainGatewayUpgrader_3_of_3 is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error StateMismatch();

    struct ContractState {
        address parameterRegistry;
        address settlementChainGateway;
        address settlementChainGatewayAlias;
        bool paused;
        string contractName;
        string version;
    }

    string internal _environment;
    uint256 internal _privateKey;
    address internal _admin;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Admin private key
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));
        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
        if (_privateKey == 0) revert PrivateKeyNotSet();
        _admin = vm.addr(_privateKey);
        console.log("Admin: %s", _admin);
    }

    function Upgrade() external {
        address proxy = _deployment.gatewayProxy;

        console.log("proxy: %s", proxy);

        // Get implementation address before upgrade
        AppChainGateway gateway = AppChainGateway(proxy);
        address implBefore = gateway.implementation();
        console.log("Implementation before upgrade: %s", implBefore);

        // Get contract state before upgrade
        bytes memory stateBefore = _getContractState(proxy);
        _logContractState("State before upgrade:", stateBefore);

        vm.startBroadcast(_privateKey);

        // Perform migration
        IMigratable(proxy).migrate();
        console.log("Migration completed");

        vm.stopBroadcast();

        // Get implementation address after upgrade
        address implAfter = gateway.implementation();
        console.log("Implementation after upgrade: %s", implAfter);

        // Compare state before and after upgrade
        bytes memory stateAfter = _getContractState(proxy);
        _logContractState("State after upgrade:", stateAfter);

        if (!_isContractStateEqual(stateBefore, stateAfter)) revert StateMismatch();

        console.log("State comparison passed - upgrade successful!");
    }

    function _getContractState(address proxy_) internal view returns (bytes memory state_) {
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
    ) internal pure returns (bool isEqual_) {
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

    function _logContractState(string memory title_, bytes memory state_) internal view {
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

