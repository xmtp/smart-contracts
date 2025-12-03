// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";
import { Utils } from "./utils/Utils.sol";
import { IERC1967 } from "../src/abstract/interfaces/IERC1967.sol";

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
 * @notice Snapshots the state of all contracts in an environment
 * @dev This script captures the current state of all contracts by calling the
 *      getContractState() function from each upgrader contract.
 *
 * Usage (for settlement chain contracts):
 *   ENVIRONMENT=testnet-dev forge script SnapshotContracts --rpc-url base_sepolia --sig "SnapshotSettlementChain()"
 *
 * Usage (for app chain contracts):
 *   ENVIRONMENT=testnet-dev forge script SnapshotContracts --rpc-url xmtp_ropsten --sig "SnapshotAppChain()"
 *
 * Note: The script outputs JSON-formatted data that can be piped to jq or redirected to a file.
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
     */
    function _getImplementation(address proxy_) internal returns (address implementation_) {
        return IERC1967(proxy_).implementation();
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
        _snapshotSettlementChainGateway();
        console.log(",");
        _snapshotSettlementChainParameterRegistry();

        console.log("");
        console.log("  }");
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
        console.log("  }");
        console.log("}");
    }

    // ============ Settlement Chain Snapshots ============

    function _snapshotNodeRegistry() internal {
        NodeRegistryUpgrader upgrader = new NodeRegistryUpgrader();
        NodeRegistryUpgrader.ContractState memory state = upgrader.getContractState(_deployment.nodeRegistryProxy);

        console.log('    "nodeRegistry": {');
        console.log('      "proxy": "%s",', _deployment.nodeRegistryProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.nodeRegistryProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
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

            // Issue warning if array is empty but nodes exist
            if (state.canonicalNodes.length == 0 && state.nodeCount > 0) {
                console.log('        "warning": "Canonical nodes array is empty but node count is non-zero",');
            }
        }

        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotPayerRegistry() internal {
        PayerRegistryUpgrader upgrader = new PayerRegistryUpgrader();
        PayerRegistryUpgrader.ContractState memory state = upgrader.getContractState(_deployment.payerRegistryProxy);

        console.log('    "payerRegistry": {');
        console.log('      "proxy": "%s",', _deployment.payerRegistryProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.payerRegistryProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "feeToken": "%s",', state.feeToken);
        console.log('        "settler": "%s",', state.settler);
        console.log('        "feeDistributor": "%s",', state.feeDistributor);
        console.log('        "paused": %s,', state.paused ? "true" : "false");
        console.log('        "totalDeposits": %s,', uint256(int256(state.totalDeposits)));
        console.log('        "totalDebt": %s,', state.totalDebt);
        console.log('        "minimumDeposit": %s,', state.minimumDeposit);
        console.log('        "withdrawLockPeriod": %s,', state.withdrawLockPeriod);
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotPayerReportManager() internal {
        PayerReportManagerUpgrader upgrader = new PayerReportManagerUpgrader();
        PayerReportManagerUpgrader.ContractState memory state = upgrader.getContractState(
            _deployment.payerReportManagerProxy
        );

        console.log('    "payerReportManager": {');
        console.log('      "proxy": "%s",', _deployment.payerReportManagerProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.payerReportManagerProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "payerRegistry": "%s",', state.payerRegistry);
        console.log('        "nodeRegistry": "%s",', state.nodeRegistry);
        console.log('        "protocolFeeRate": %s,', state.protocolFeeRate);
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotRateRegistry() internal {
        RateRegistryUpgrader upgrader = new RateRegistryUpgrader();
        RateRegistryUpgrader.ContractState memory state = upgrader.getContractState(_deployment.rateRegistryProxy);

        console.log('    "rateRegistry": {');
        console.log('      "proxy": "%s",', _deployment.rateRegistryProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.rateRegistryProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "ratesCount": %s,', state.ratesCount);
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotDistributionManager() internal {
        DistributionManagerUpgrader upgrader = new DistributionManagerUpgrader();
        DistributionManagerUpgrader.ContractState memory state = upgrader.getContractState(
            _deployment.distributionManagerProxy
        );

        console.log('    "distributionManager": {');
        console.log('      "proxy": "%s",', _deployment.distributionManagerProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.distributionManagerProxy));
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
        console.log("    }");
    }

    function _snapshotFeeToken() internal {
        FeeTokenUpgrader upgrader = new FeeTokenUpgrader();
        FeeTokenUpgrader.ContractState memory state = upgrader.getContractState(_deployment.feeTokenProxy);

        console.log('    "feeToken": {');
        console.log('      "proxy": "%s",', _deployment.feeTokenProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.feeTokenProxy));
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
        console.log("    }");
    }

    function _snapshotSettlementChainGateway() internal {
        SettlementChainGatewayUpgrader upgrader = new SettlementChainGatewayUpgrader();
        SettlementChainGatewayUpgrader.ContractState memory state = upgrader.getContractState(_deployment.gatewayProxy);

        console.log('    "settlementChainGateway": {');
        console.log('      "proxy": "%s",', _deployment.gatewayProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.gatewayProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "appChainGateway": "%s",', state.appChainGateway);
        console.log('        "feeToken": "%s",', state.feeToken);
        console.log('        "paused": %s,', state.paused ? "true" : "false");
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotSettlementChainParameterRegistry() internal {
        SettlementChainParameterRegistryUpgrader upgrader = new SettlementChainParameterRegistryUpgrader();
        SettlementChainParameterRegistryUpgrader.ContractState memory state = upgrader.getContractState(
            _deployment.parameterRegistryProxy
        );

        console.log('    "settlementChainParameterRegistry": {');
        console.log('      "proxy": "%s",', _deployment.parameterRegistryProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.parameterRegistryProxy));
        console.log('      "state": {');
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    // ============ App Chain Snapshots ============

    function _snapshotAppChainGateway() internal {
        AppChainGatewayUpgrader upgrader = new AppChainGatewayUpgrader();
        AppChainGatewayUpgrader.ContractState memory state = upgrader.getContractState(_deployment.gatewayProxy);

        console.log('    "appChainGateway": {');
        console.log('      "proxy": "%s",', _deployment.gatewayProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.gatewayProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "settlementChainGateway": "%s",', state.settlementChainGateway);
        console.log('        "settlementChainGatewayAlias": "%s",', state.settlementChainGatewayAlias);
        console.log('        "paused": %s,', state.paused ? "true" : "false");
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotAppChainParameterRegistry() internal {
        AppChainParameterRegistryUpgrader upgrader = new AppChainParameterRegistryUpgrader();
        AppChainParameterRegistryUpgrader.ContractState memory state = upgrader.getContractState(
            _deployment.parameterRegistryProxy
        );

        console.log('    "appChainParameterRegistry": {');
        console.log('      "proxy": "%s",', _deployment.parameterRegistryProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.parameterRegistryProxy));
        console.log('      "state": {');
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotGroupMessageBroadcaster() internal {
        GroupMessageBroadcasterUpgrader upgrader = new GroupMessageBroadcasterUpgrader();
        GroupMessageBroadcasterUpgrader.ContractState memory state = upgrader.getContractState(
            _deployment.groupMessageBroadcasterProxy
        );

        console.log('    "groupMessageBroadcaster": {');
        console.log('      "proxy": "%s",', _deployment.groupMessageBroadcasterProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.groupMessageBroadcasterProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "minPayloadSize": %s,', state.minPayloadSize);
        console.log('        "maxPayloadSize": %s,', state.maxPayloadSize);
        console.log('        "payloadBootstrapper": "%s",', state.payloadBootstrapper);
        console.log('        "paused": %s,', state.paused ? "true" : "false");
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }

    function _snapshotIdentityUpdateBroadcaster() internal {
        IdentityUpdateBroadcasterUpgrader upgrader = new IdentityUpdateBroadcasterUpgrader();
        IdentityUpdateBroadcasterUpgrader.ContractState memory state = upgrader.getContractState(
            _deployment.identityUpdateBroadcasterProxy
        );

        console.log('    "identityUpdateBroadcaster": {');
        console.log('      "proxy": "%s",', _deployment.identityUpdateBroadcasterProxy);
        console.log('      "implementation": "%s",', _getImplementation(_deployment.identityUpdateBroadcasterProxy));
        console.log('      "state": {');
        console.log('        "parameterRegistry": "%s",', state.parameterRegistry);
        console.log('        "minPayloadSize": %s,', state.minPayloadSize);
        console.log('        "maxPayloadSize": %s,', state.maxPayloadSize);
        console.log('        "payloadBootstrapper": "%s",', state.payloadBootstrapper);
        console.log('        "paused": %s,', state.paused ? "true" : "false");
        console.log('        "contractName": "%s",', state.contractName);
        console.log('        "version": "%s"', state.version);
        console.log("      }");
        console.log("    }");
    }
}
