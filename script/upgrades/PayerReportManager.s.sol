// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { GenericEIP1967Migrator } from "../../../src/any-chain/GenericEIP1967Migrator.sol";
import { IERC1967 } from "../../../src/abstract/interfaces/IERC1967.sol";

import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { Utils } from "../../script/utils/Utils.sol";
import { PayerReportManager } from "../../src/settlement-chain/PayerReportManager.sol";
import { PayerReportManagerDeployer } from "../deployers/PayerReportManagerDeployer.sol";

contract PayerReportManagerUpgrader is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();

    string internal _environment;

    uint256 internal _privateKey;
    address internal _admin;

    Utils.DeploymentData internal deployment;

    function setUp() external {
        _environment = vm.envString("ENVIRONMENT");

        if (bytes(_environment).length == 0) revert EnvironmentNotSet();

        console.log("Environment: %s", _environment);

        deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));

        if (_privateKey == 0) revert PrivateKeyNotSet();

        _admin = vm.addr(_privateKey);

        console.log("Admin: %s", _admin);
    }

    function UpgradePayerReportManager() external {
        address factory = deployment.factory;
        console.log("factory", factory);
        address paramRegistry = deployment.parameterRegistryProxy;
        console.log("paramRegistry", paramRegistry);
        address proxy = deployment.payerReportManagerProxy;
        console.log("proxy", proxy);
        address nodeRegistry = deployment.nodeRegistryProxy;
        console.log("nodeRegistry", nodeRegistry);
        address payerRegistry = deployment.payerRegistryProxy;
        console.log("payerRegistry", payerRegistry);

        vm.startBroadcast(_privateKey);
        (address newImpl, ) = PayerReportManagerDeployer.deployImplementation(
            factory,
            paramRegistry,
            nodeRegistry,
            payerRegistry
        );
        console.log("newImpl", newImpl);

        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator", address(migrator));
        string memory key = PayerReportManager(proxy).migratorParameterKey();
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));

        PayerReportManager(proxy).migrate();

        vm.stopBroadcast();
    }
}
