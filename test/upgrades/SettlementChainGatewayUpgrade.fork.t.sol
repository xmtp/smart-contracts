// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { SettlementChainGateway } from "../../src/settlement-chain/SettlementChainGateway.sol";

import { SettlementChainGatewayDeployer } from "../../script/deployers/SettlementChainGatewayDeployer.sol";
import { GenericEIP1967Migrator } from "../../src/any-chain/GenericEIP1967Migrator.sol";
import { Utils } from "../../script/utils/Utils.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";

interface ISettlementChainGateway {
    function parameterRegistry() external view returns (address);
    function appChainGateway() external view returns (address);
    function feeToken() external view returns (address);
    function migrate() external;
    function migratorParameterKey() external pure returns (string memory);
}

contract SettlementChainGatewayUpgradeForkTest is Test {
    address constant admin = 0x560469CBb7D1E29c7d56EfE765B21FbBaC639dC7;

    Utils.DeploymentData internal deployment;

    function setUp() external {
        // Hardcoded environment and RPC
        string memory rpc = "https://sepolia.base.org";
        vm.createSelectFork(rpc);

        string memory environment = "testnet-staging";
        deployment = Utils.parseDeploymentData(string.concat("config/", environment, ".json"));
    }

    function test_upgrade_settlement_gateway() external {
        address factory = deployment.factory;
        address paramRegistry = deployment.parameterRegistryProxy;
        address settlementChainGateway = deployment.gatewayProxy;
        address feeToken = deployment.feeTokenProxy;

        address oldImpl = IERC1967(settlementChainGateway).implementation();

        (address newImpl, ) = SettlementChainGatewayDeployer.deployImplementation(
            factory,
            paramRegistry,
            settlementChainGateway,
            feeToken
        );

        // Deploy migrator
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);

        // Set the migrator in ParameterRegistry (impersonate admin)
        vm.startPrank(admin);
        string memory key = ISettlementChainGateway(settlementChainGateway).migratorParameterKey();
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));
        vm.stopPrank();

        // Execute migration
        ISettlementChainGateway(settlementChainGateway).migrate();

        vm.expectEmit(true, true, true, true);
        emit IMigratable.Migrated(address(migrator));

        // Confirm the implementation changed
        address afterImpl = IERC1967(settlementChainGateway).implementation();
        assertEq(afterImpl, newImpl, "Implementation did not update");
    }
}
