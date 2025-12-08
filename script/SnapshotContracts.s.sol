// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";
import { Utils } from "./utils/Utils.sol";
import { ParameterSnapshotter } from "./utils/ParameterSnapshotter.sol";
import { IERC1967 } from "../src/abstract/interfaces/IERC1967.sol";
import { IIdentified } from "../src/abstract/interfaces/IIdentified.sol";
import { IParameterRegistry } from "../src/abstract/interfaces/IParameterRegistry.sol";

// Settlement chain upgraders
import { NodeRegistryUpgrader } from "./upgrades/settlement-chain/NodeRegistryUpgrader.s.sol";
import { PayerRegistryUpgrader } from "./upgrades/settlement-chain/PayerRegistryUpgrader.s.sol";
import { PayerReportManagerUpgrader } from "./upgrades/settlement-chain/PayerReportManagerUpgrader.s.sol";
import { RateRegistryUpgrader } from "./upgrades/settlement-chain/RateRegistryUpgrader.s.sol";
import { DistributionManagerUpgrader } from "./upgrades/settlement-chain/DistributionManagerUpgrader.s.sol";
import { FeeTokenUpgrader } from "./upgrades/settlement-chain/FeeTokenUpgrader.s.sol";
import { SettlementChainGatewayUpgrader } from "./upgrades/settlement-chain/SettlementChainGatewayUpgrader.s.sol";
import {
    SettlementChainParameterRegistryUpgrader
} from "./upgrades/settlement-chain/SettlementChainParameterRegistryUpgrader.s.sol";

// App chain upgraders
import { AppChainGatewayUpgrader } from "./upgrades/app-chain/AppChainGatewayUpgrader.s.sol";
import { AppChainParameterRegistryUpgrader } from "./upgrades/app-chain/AppChainParameterRegistryUpgrader.s.sol";
import { GroupMessageBroadcasterUpgrader } from "./upgrades/app-chain/GroupMessageBroadcasterUpgrader.s.sol";
import { IdentityUpdateBroadcasterUpgrader } from "./upgrades/app-chain/IdentityUpdateBroadcasterUpgrader.s.sol";

/**
 * @notice Snapshots the state of all contracts and parameters in an environment
 * @dev This script captures the current state of all contracts by calling the
 *      getContractState() function from each upgrader contract, and also snapshots
 *      all parameter keys and their values from the parameter registry.
 *
 * Usage (for settlement chain contracts):
 *   ENVIRONMENT=testnet-dev forge script SnapshotContracts --rpc-url base_sepolia --sig "SnapshotSettlementChain()"
 *
 * Usage (for app chain contracts):
 *   ENVIRONMENT=testnet-dev forge script SnapshotContracts --rpc-url xmtp_ropsten --sig "SnapshotAppChain()"
 *
 * Note: The script outputs JSON-formatted data that can be piped to jq or redirected to a file.
 *       The output includes both contract states and parameter registry values.
 */
contract SnapshotContracts is Script {
    error EnvironmentNotSet();

    string internal _environment;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));
    }

    /**
     * @notice Helper to get implementation address from any EIP1967 proxy
     * @dev Returns address(0) if the call fails (e.g., contract doesn't implement IERC1967)
     */
    function _getImplementation(address proxy_) internal view returns (address implementation_) {
        try IERC1967(proxy_).implementation() returns (address impl) {
            return impl;
        } catch {
            return address(0);
        }
    }

    /**
     * @notice Helper to check if a contract exists at an address
     */
    function _contractExists(address address_) internal view returns (bool exists_) {
        return address_.code.length > 0;
    }

    /**
     * @notice Snapshots all settlement chain contracts
     * @dev Run this on the settlement chain RPC
     */
    function SnapshotSettlementChain() external {
        console.log("{");
        console.log('  "chain": "settlement-chain",');
        console.log('  "chainId": %s,', _deployment.settlementChainId);
        console.log('  "environment": "%s",', _environment);
        console.log('  "contracts": {');

        _snapshotNodeRegistry();
        console.log(",");
        _snapshotPayerRegistry();
        console.log(",");
        _snapshotPayerReportManager();
        console.log(",");
        _snapshotRateRegistry();
        console.log(",");
        _snapshotDistributionManager();
        console.log(",");
        _snapshotFeeToken();
        console.log(",");
        _snapshotDepositSplitter();
        console.log(",");
        _snapshotSettlementChainGateway();
        console.log(",");
        _snapshotSettlementChainParameterRegistry();

        console.log("");
        console.log("  },");
        _snapshotParameters();

        console.log("");
        console.log("}");
    }

    /**
     * @notice Snapshots all app chain contracts
     * @dev Run this on the app chain RPC
     */
    function SnapshotAppChain() external {
        console.log("{");
        console.log('  "chain": "app-chain",');
        console.log('  "chainId": %s,', _deployment.appChainId);
        console.log('  "environment": "%s",', _environment);
        console.log('  "contracts": {');

        _snapshotAppChainGateway();
        console.log(",");
        _snapshotAppChainParameterRegistry();
        console.log(",");
        _snapshotGroupMessageBroadcaster();
        console.log(",");
        _snapshotIdentityUpdateBroadcaster();

        console.log("");
        console.log("  },");
        _snapshotParameters();

        console.log("");
        console.log("}");
    }

    // ============ Settlement Chain Snapshots ============

    function _snapshotNodeRegistry() internal {
        console.log('    "nodeRegistry": {');
        console.log('      "proxy": "%s",', _deployment.nodeRegistryProxy);

        if (!_contractExists(_deployment.nodeRegistryProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.nodeRegistryProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        NodeRegistryUpgrader upgrader = new NodeRegistryUpgrader();
        try upgrader.getContractState(_deployment.nodeRegistryProxy) returns (
            NodeRegistryUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "maxCanonicalNodes": %s,', uint256(state.maxCanonicalNodes));
            console.log('        "canonicalNodesCount": %s,', uint256(state.canonicalNodesCount));
            console.log('        "nodeCount": %s,', uint256(state.nodeCount));

            // Output canonical nodes array if available
            if (state.hasGetCanonicalNodesFunction) {
                console.log('        "canonicalNodes": [');
                for (uint256 i = 0; i < state.canonicalNodes.length; i++) {
                    if (i < state.canonicalNodes.length - 1) {
                        console.log("          %s,", uint256(state.canonicalNodes[i]));
                    } else {
                        console.log("          %s", uint256(state.canonicalNodes[i]));
                    }
                }
                console.log("        ],");
            }

            // Output all nodes array
            console.log('        "allNodes": [');
            for (uint256 i = 0; i < state.allNodes.length; i++) {
                console.log("          {");
                console.log('            "nodeId": %s,', uint256(state.allNodes[i].nodeId));
                console.log('            "signer": "%s",', state.allNodes[i].node.signer);
                console.log('            "isCanonical": %s,', state.allNodes[i].node.isCanonical ? "true" : "false");
                console.log('            "httpAddress": "%s"', state.allNodes[i].node.httpAddress);
                if (i < state.allNodes.length - 1) {
                    console.log("          },");
                } else {
                    console.log("          }");
                }
            }
            console.log("        ],");

            console.log('        "admin": "%s",', state.admin);
            console.log('        "adminParameterKey": "%s",', state.adminParameterKey);
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotPayerRegistry() internal {
        console.log('    "payerRegistry": {');
        console.log('      "proxy": "%s",', _deployment.payerRegistryProxy);

        if (!_contractExists(_deployment.payerRegistryProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.payerRegistryProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        PayerRegistryUpgrader upgrader = new PayerRegistryUpgrader();
        try upgrader.getContractState(_deployment.payerRegistryProxy) returns (
            PayerRegistryUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "feeToken": "%s",', state.feeToken);
            console.log('        "settler": "%s",', state.settler);
            console.log('        "feeDistributor": "%s",', state.feeDistributor);
            console.log('        "paused": %s,', state.paused ? "true" : "false");

            // Handle potentially negative totalDeposits
            if (state.totalDeposits >= 0) {
                console.log('        "totalDeposits": %s,', uint256(int256(state.totalDeposits)));
            } else {
                console.log('        "totalDeposits": -%s,', uint256(-int256(state.totalDeposits)));
            }

            console.log('        "totalDebt": %s,', state.totalDebt);
            console.log('        "minimumDeposit": %s,', state.minimumDeposit);
            console.log('        "withdrawLockPeriod": %s,', state.withdrawLockPeriod);
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotPayerReportManager() internal {
        console.log('    "payerReportManager": {');
        console.log('      "proxy": "%s",', _deployment.payerReportManagerProxy);

        if (!_contractExists(_deployment.payerReportManagerProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.payerReportManagerProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        PayerReportManagerUpgrader upgrader = new PayerReportManagerUpgrader();
        try upgrader.getContractState(_deployment.payerReportManagerProxy) returns (
            PayerReportManagerUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "payerRegistry": "%s",', state.payerRegistry);
            console.log('        "nodeRegistry": "%s",', state.nodeRegistry);
            console.log('        "protocolFeeRate": %s,', state.protocolFeeRate);
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotRateRegistry() internal {
        console.log('    "rateRegistry": {');
        console.log('      "proxy": "%s",', _deployment.rateRegistryProxy);

        if (!_contractExists(_deployment.rateRegistryProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.rateRegistryProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        RateRegistryUpgrader upgrader = new RateRegistryUpgrader();
        try upgrader.getContractState(_deployment.rateRegistryProxy) returns (
            RateRegistryUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "ratesCount": %s,', state.ratesCount);
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotDistributionManager() internal {
        console.log('    "distributionManager": {');
        console.log('      "proxy": "%s",', _deployment.distributionManagerProxy);

        if (!_contractExists(_deployment.distributionManagerProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.distributionManagerProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        DistributionManagerUpgrader upgrader = new DistributionManagerUpgrader();
        try upgrader.getContractState(_deployment.distributionManagerProxy) returns (
            DistributionManagerUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "nodeRegistry": "%s",', state.nodeRegistry);
            console.log('        "payerReportManager": "%s",', state.payerReportManager);
            console.log('        "payerRegistry": "%s",', state.payerRegistry);
            console.log('        "feeToken": "%s",', state.feeToken);
            console.log('        "protocolFeesRecipient": "%s",', state.protocolFeesRecipient);
            console.log('        "paused": %s,', state.paused ? "true" : "false");
            console.log('        "owedProtocolFees": %s,', state.owedProtocolFees);
            console.log('        "totalOwedFees": %s,', state.totalOwedFees);
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotFeeToken() internal {
        console.log('    "feeToken": {');
        console.log('      "proxy": "%s",', _deployment.feeTokenProxy);

        if (!_contractExists(_deployment.feeTokenProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.feeTokenProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        FeeTokenUpgrader upgrader = new FeeTokenUpgrader();
        try upgrader.getContractState(_deployment.feeTokenProxy) returns (FeeTokenUpgrader.ContractState memory state) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "underlying": "%s",', state.underlying);
            console.log('        "name": "%s",', state.name);
            console.log('        "symbol": "%s",', state.symbol);
            console.log('        "decimals": %s,', uint256(state.decimals));
            console.log('        "totalSupply": %s,', state.totalSupply);
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotDepositSplitter() internal {
        console.log('    "depositSplitter": {');
        console.log('      "address": "%s",', _deployment.depositSplitter);

        if (!_contractExists(_deployment.depositSplitter)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        console.log('      "exists": true,');

        string memory contractName_;
        string memory version_;

        try IIdentified(_deployment.depositSplitter).contractName() returns (string memory name_) {
            contractName_ = name_;
        } catch {
            contractName_ = "";
        }

        try IIdentified(_deployment.depositSplitter).version() returns (string memory ver_) {
            version_ = ver_;
        } catch {
            version_ = "";
        }

        console.log('      "contractName": "%s",', contractName_);
        console.log('      "version": "%s"', version_);
        console.log("    }");
    }

    function _snapshotSettlementChainGateway() internal {
        console.log('    "settlementChainGateway": {');
        console.log('      "proxy": "%s",', _deployment.gatewayProxy);

        if (!_contractExists(_deployment.gatewayProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.gatewayProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        SettlementChainGatewayUpgrader upgrader = new SettlementChainGatewayUpgrader();
        try upgrader.getContractState(_deployment.gatewayProxy) returns (
            SettlementChainGatewayUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "appChainGateway": "%s",', state.appChainGateway);
            console.log('        "feeToken": "%s",', state.feeToken);
            console.log('        "paused": %s,', state.paused ? "true" : "false");
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotSettlementChainParameterRegistry() internal {
        console.log('    "settlementChainParameterRegistry": {');
        console.log('      "proxy": "%s",', _deployment.parameterRegistryProxy);

        if (!_contractExists(_deployment.parameterRegistryProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.parameterRegistryProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        SettlementChainParameterRegistryUpgrader upgrader = new SettlementChainParameterRegistryUpgrader();
        try upgrader.getContractState(_deployment.parameterRegistryProxy) returns (
            SettlementChainParameterRegistryUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    // ============ App Chain Snapshots ============

    function _snapshotAppChainGateway() internal {
        console.log('    "appChainGateway": {');
        console.log('      "proxy": "%s",', _deployment.gatewayProxy);

        if (!_contractExists(_deployment.gatewayProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.gatewayProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        AppChainGatewayUpgrader upgrader = new AppChainGatewayUpgrader();
        try upgrader.getContractState(_deployment.gatewayProxy) returns (
            AppChainGatewayUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "settlementChainGateway": "%s",', state.settlementChainGateway);
            console.log('        "settlementChainGatewayAlias": "%s",', state.settlementChainGatewayAlias);
            console.log('        "paused": %s,', state.paused ? "true" : "false");
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotAppChainParameterRegistry() internal {
        console.log('    "appChainParameterRegistry": {');
        console.log('      "proxy": "%s",', _deployment.parameterRegistryProxy);

        if (!_contractExists(_deployment.parameterRegistryProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.parameterRegistryProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        AppChainParameterRegistryUpgrader upgrader = new AppChainParameterRegistryUpgrader();
        try upgrader.getContractState(_deployment.parameterRegistryProxy) returns (
            AppChainParameterRegistryUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotGroupMessageBroadcaster() internal {
        console.log('    "groupMessageBroadcaster": {');
        console.log('      "proxy": "%s",', _deployment.groupMessageBroadcasterProxy);

        if (!_contractExists(_deployment.groupMessageBroadcasterProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.groupMessageBroadcasterProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        GroupMessageBroadcasterUpgrader upgrader = new GroupMessageBroadcasterUpgrader();
        try upgrader.getContractState(_deployment.groupMessageBroadcasterProxy) returns (
            GroupMessageBroadcasterUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "minPayloadSize": %s,', state.minPayloadSize);
            console.log('        "maxPayloadSize": %s,', state.maxPayloadSize);
            console.log('        "payloadBootstrapper": "%s",', state.payloadBootstrapper);
            console.log('        "paused": %s,', state.paused ? "true" : "false");
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    function _snapshotIdentityUpdateBroadcaster() internal {
        console.log('    "identityUpdateBroadcaster": {');
        console.log('      "proxy": "%s",', _deployment.identityUpdateBroadcasterProxy);

        if (!_contractExists(_deployment.identityUpdateBroadcasterProxy)) {
            console.log('      "exists": false');
            console.log("    }");
            return;
        }

        address impl = _getImplementation(_deployment.identityUpdateBroadcasterProxy);
        console.log('      "exists": true,');
        console.log('      "implementation": "%s",', impl);

        IdentityUpdateBroadcasterUpgrader upgrader = new IdentityUpdateBroadcasterUpgrader();
        try upgrader.getContractState(_deployment.identityUpdateBroadcasterProxy) returns (
            IdentityUpdateBroadcasterUpgrader.ContractState memory state
        ) {
            console.log('      "state": {');
            console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
            console.log('        "minPayloadSize": %s,', state.minPayloadSize);
            console.log('        "maxPayloadSize": %s,', state.maxPayloadSize);
            console.log('        "payloadBootstrapper": "%s",', state.payloadBootstrapper);
            console.log('        "paused": %s,', state.paused ? "true" : "false");
            console.log('        "contractName": "%s",', state.contractName);
            console.log('        "version": "%s"', state.version);
            console.log("      }");
        } catch {
            console.log('      "state": null,');
            console.log('      "error": "Failed to get contract state"');
        }
        console.log("    }");
    }

    // ============ Parameter Snapshotting ============

    /**
     * @notice Snapshots all parameter keys and their values from the parameter registry
     */
    function _snapshotParameters() internal view {
        console.log('  "parameters": {');
        console.log('    "parameterRegistry": "%s",', _deployment.parameterRegistryProxy);

        if (!_contractExists(_deployment.parameterRegistryProxy)) {
            console.log('    "exists": false,');
            console.log('    "values": {}');
            console.log("  }");
            return;
        }

        console.log('    "exists": true,');
        console.log('    "values": {');

        // Get all known keys and sort them
        string[] memory keys = ParameterSnapshotter.getAllKnownKeys();
        ParameterSnapshotter.sortKeys(keys);

        // Query values from parameter registry
        IParameterRegistry parameterRegistry = IParameterRegistry(_deployment.parameterRegistryProxy);
        bytes32[] memory values = ParameterSnapshotter.queryParameterValues(parameterRegistry, keys);

        // Output all keys with their values
        for (uint256 i = 0; i < keys.length; i++) {
            string memory jsonLine = ParameterSnapshotter.formatValueAsJson(vm, keys[i], values[i]);
            if (i < keys.length - 1) {
                console.log("%s,", jsonLine);
            } else {
                console.log("%s", jsonLine);
            }
        }

        console.log("    }");
        console.log("  }");
    }
}
