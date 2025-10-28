// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { GenericEIP1967Migrator } from "../../../src/any-chain/GenericEIP1967Migrator.sol";
import { IERC1967 } from "../../../src/abstract/interfaces/IERC1967.sol";

import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { SettlementChainGateway } from "../../../src/settlement-chain/SettlementChainGateway.sol";
import { SettlementChainGatewayDeployer } from "../../../script/deployers/SettlementChainGatewayDeployer.sol";
import { Utils } from "../../script/utils/Utils.sol";

interface ISettlementChainGateway {
    function parameterRegistry() external view returns (address);
    function appChainGateway() external view returns (address);
    function feeToken() external view returns (address);
    function migrate() external;
    function migratorParameterKey() external pure returns (string memory);
}

contract SettlementChainGatewayUpgrader is Script {
    error PrivateKeyNotSet();

    uint256 internal _privateKey;
    address internal _admin;

    Utils.DeploymentData internal deployment;

    function setUp() external {
        string memory environment = "anvil";
        deployment = Utils.parseDeploymentData(string.concat("config/", environment, ".json"));

        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));

        if (_privateKey == 0) revert PrivateKeyNotSet();

        _admin = vm.addr(_privateKey);

        console.log("Admin: %s", _admin);
    }

    function UpgradeSettlementChainGateway() external {
        address factory = deployment.factory;
        console.log("factory" , factory);
        address paramRegistry = deployment.parameterRegistryProxy;
        console.log("paramRegistry" , paramRegistry);
        address settlementChainGateway = deployment.gatewayProxy;
        console.log("settlementChainGateway" , settlementChainGateway);
        address feeToken = deployment.feeTokenProxy;
        console.log("feeToken" , feeToken);
        address proxy = deployment.gatewayProxy;
        console.log("proxy" , proxy);

        vm.startBroadcast(_privateKey);
        (address newImpl, ) = SettlementChainGatewayDeployer.deployImplementation(
            factory,
            paramRegistry,
            settlementChainGateway,
            feeToken
        );
        console.log("newImpl", newImpl);

        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator", address(migrator));
        string memory key = ISettlementChainGateway(proxy).migratorParameterKey();
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));

        SettlementChainGateway(settlementChainGateway).migrate();

        vm.stopBroadcast();
    }
}
