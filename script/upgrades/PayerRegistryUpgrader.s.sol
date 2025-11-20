// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../lib/forge-std/src/Script.sol";
import { PayerRegistry } from "../../src/settlement-chain/PayerRegistry.sol";
import { BaseUpgrader } from "./BaseUpgrader.s.sol";
import { PayerRegistryDeployer } from "../deployers/PayerRegistryDeployer.sol";

contract PayerRegistryUpgrader is BaseUpgrader {
    struct ContractState {
        address parameterRegistry;
        address feeToken;
        address settler;
        address feeDistributor;
        bool paused;
        int104 totalDeposits;
        uint96 totalDebt;
        uint96 minimumDeposit;
        uint32 withdrawLockPeriod;
        string contractName;
        string version;
    }

    function UpgradePayerRegistry() external {
        _upgrade();
    }

    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.payerRegistryProxy;
    }

    function _deployOrGetImplementation() internal override returns (address implementation_) {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address feeToken = _deployment.feeTokenProxy;

        // Compute implementation address
        address computedImpl = PayerRegistryDeployer.getImplementation(factory, paramRegistry, feeToken);

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = PayerRegistryDeployer.deployImplementation(factory, paramRegistry, feeToken);
    }

    function _getMigratorParameterKey(address proxy_) internal view override returns (string memory key_) {
        return PayerRegistry(proxy_).migratorParameterKey();
    }

    function _getContractState(address proxy_) internal view override returns (bytes memory state_) {
        ContractState memory state = _getPayerRegistryState(proxy_);
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
            before.feeToken == afterState.feeToken &&
            before.settler == afterState.settler &&
            before.feeDistributor == afterState.feeDistributor &&
            before.paused == afterState.paused &&
            before.totalDeposits == afterState.totalDeposits &&
            before.totalDebt == afterState.totalDebt &&
            before.minimumDeposit == afterState.minimumDeposit &&
            before.withdrawLockPeriod == afterState.withdrawLockPeriod;

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
        console.log("  Fee token: %s", state.feeToken);
        console.log("  Settler: %s", state.settler);
        console.log("  Fee distributor: %s", state.feeDistributor);
        console.log("  Paused: %s", state.paused);
        console.log("  Total deposits: %s", uint256(uint104(state.totalDeposits)));
        console.log("  Total debt: %s", uint256(state.totalDebt));
        console.log("  Minimum deposit: %s", uint256(state.minimumDeposit));
        console.log("  Withdraw lock period: %s", uint256(state.withdrawLockPeriod));
        console.log("  Name: %s", state.contractName);
        console.log("  Version: %s", state.version);
    }

    function _getPayerRegistryState(address proxy_) internal view returns (ContractState memory state_) {
        PayerRegistry payerRegistry = PayerRegistry(proxy_);
        state_.parameterRegistry = payerRegistry.parameterRegistry();
        state_.feeToken = payerRegistry.feeToken();
        state_.settler = payerRegistry.settler();
        state_.feeDistributor = payerRegistry.feeDistributor();
        state_.paused = payerRegistry.paused();
        state_.totalDeposits = payerRegistry.totalDeposits();
        state_.totalDebt = payerRegistry.totalDebt();
        state_.minimumDeposit = payerRegistry.minimumDeposit();
        state_.withdrawLockPeriod = payerRegistry.withdrawLockPeriod();

        // Try to get contractName and version, which may not exist in older implementations
        try payerRegistry.contractName() returns (string memory contractName_) {
            state_.contractName = contractName_;
        } catch {
            state_.contractName = "";
        }

        try payerRegistry.version() returns (string memory version_) {
            state_.version = version_;
        } catch {
            state_.version = "";
        }
    }

    // Public functions for testing
    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        return _getPayerRegistryState(proxy_);
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory afterState_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == afterState_.parameterRegistry &&
            before_.feeToken == afterState_.feeToken &&
            before_.settler == afterState_.settler &&
            before_.feeDistributor == afterState_.feeDistributor &&
            before_.paused == afterState_.paused &&
            before_.totalDeposits == afterState_.totalDeposits &&
            before_.totalDebt == afterState_.totalDebt &&
            before_.minimumDeposit == afterState_.minimumDeposit &&
            before_.withdrawLockPeriod == afterState_.withdrawLockPeriod;

        // Only check contractName if it existed in the before state (non-empty)
        // This handles upgrades from old versions without contractName to new versions with it
        if (bytes(before_.contractName).length > 0) {
            isEqual_ = isEqual_ && keccak256(bytes(before_.contractName)) == keccak256(bytes(afterState_.contractName));
        }
        // Note: version is intentionally not checked, it can change
    }
}
