// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { PayerReportManager } from "../../src/settlement-chain/PayerReportManager.sol";

import { GenericEIP1967Migrator } from "../../src/any-chain/GenericEIP1967Migrator.sol";
import { Utils } from "../../script/utils/Utils.sol";
import { PayerReportManagerDeployer } from "../../script/deployers/PayerReportManagerDeployer.sol";
import { PayerReportManagerUpgrader } from "../../script/upgrades/PayerReportManagerUpgrader.s.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";

contract PayerReportManagerUpgradeForkTest is Test {
    address constant admin = 0x560469CBb7D1E29c7d56EfE765B21FbBaC639dC7;

    Utils.DeploymentData internal deployment;
    PayerReportManagerUpgrader internal upgrader;

    function setUp() external {
        // Hardcoded environment and RPC
        string memory rpc = vm.rpcUrl("base_sepolia");
        vm.createSelectFork(rpc);

        string memory environment = "testnet-staging";
        deployment = Utils.parseDeploymentData(string.concat("config/", environment, ".json"));

        upgrader = new PayerReportManagerUpgrader();
    }

    function test_payer_report_manager() external {
        address factory = deployment.factory;
        address paramRegistry = deployment.parameterRegistryProxy;
        address proxy = deployment.payerReportManagerProxy;
        address nodeRegistry = deployment.nodeRegistryProxy;
        address payerRegistry = deployment.payerRegistryProxy;

        // Get state before upgrade using script's getContractState
        PayerReportManagerUpgrader.ContractState memory stateBefore = upgrader.getContractState(proxy);

        // Compute the implementation address
        address computedImpl = PayerReportManagerDeployer.getImplementation(
            factory,
            paramRegistry,
            nodeRegistry,
            payerRegistry
        );

        address newImpl;
        if (computedImpl.code.length > 0) {
            // Implementation already exists, use it directly
            newImpl = computedImpl;
        } else {
            // Deploy new implementation
            (newImpl, ) = PayerReportManagerDeployer.deployImplementation(
                factory,
                paramRegistry,
                nodeRegistry,
                payerRegistry
            );
        }

        // Deploy migrator
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);

        // Set the migrator in ParameterRegistry (impersonate admin)
        vm.startPrank(admin);
        string memory key = PayerReportManager(proxy).migratorParameterKey();
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit IMigratable.Migrated(address(migrator));

        // Execute migration
        PayerReportManager(proxy).migrate();

        // Confirm the implementation changed
        address afterImpl = IERC1967(proxy).implementation();
        assertEq(afterImpl, newImpl, "Implementation did not update");

        // Get state after upgrade using script's getContractState
        PayerReportManagerUpgrader.ContractState memory stateAfter = upgrader.getContractState(proxy);

        // Validate state using script's isContractStateEqual
        bool statesMatch = upgrader.isContractStateEqual(stateBefore, stateAfter);
        assertTrue(statesMatch, "State mismatch after upgrade");
    }
}
