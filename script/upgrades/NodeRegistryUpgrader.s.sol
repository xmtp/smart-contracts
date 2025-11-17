// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";
import { GenericEIP1967Migrator } from "../../src/any-chain/GenericEIP1967Migrator.sol";
import { NodeRegistry } from "../../src/settlement-chain/NodeRegistry.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { Utils } from "../utils/Utils.sol";
import { NodeRegistryDeployer } from "../deployers/NodeRegistryDeployer.sol";

contract NodeRegistryUpgrader is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error StateMismatch();

    struct ContractState {
        address parameterRegistry;
        uint8 canonicalNodesCount;
        uint32 nodeCount;
    }

    string internal _environment;
    uint256 internal _privateKey;
    address internal _admin;
    Utils.DeploymentData internal deployment;
    ContractState internal contractStateBefore;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Admin private key
        deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));
        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
        if (_privateKey == 0) revert PrivateKeyNotSet();
        _admin = vm.addr(_privateKey);
        console.log("Admin: %s", _admin);

        // Contract state before upgrade
        address proxy = deployment.nodeRegistryProxy;
        contractStateBefore = getContractState(proxy);
    }

    function UpgradeNodeRegistry() external {
        address factory = deployment.factory;
        console.log("factory", factory);
        address paramRegistry = deployment.parameterRegistryProxy;
        console.log("paramRegistry", paramRegistry);
        address feeToken = deployment.feeTokenProxy;
        console.log("feeToken", feeToken);
        address proxy = deployment.nodeRegistryProxy;
        console.log("proxy", proxy);

        vm.startBroadcast(_privateKey);
        // Deploy new implementation, can be called by ANY address
        (address newImpl, ) = NodeRegistryDeployer.deployImplementation(factory, paramRegistry);
        console.log("newImpl", newImpl);

        // Deploy generic migrator, can be called by ANY address
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator (also param reg migrator value)", address(migrator));

        // Parameter registry stores the migrator address, must be called by a param registry admin address
        string memory key = NodeRegistry(proxy).migratorParameterKey();
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));
        console.log("param reg migrator key", key);

        // Perform migration, can be called by any address
        NodeRegistry(proxy).migrate();
        vm.stopBroadcast();

        // Compare state before and after upgrade
        ContractState memory contractStateAfter = getContractState(proxy);
        _logContractState("State before upgrade:", contractStateBefore);
        _logContractState("State after upgrade:", contractStateAfter);
        if (!isContractStateEqual(contractStateBefore, contractStateAfter)) revert StateMismatch();

        // Update environment file
        _writeNodeRegistryImplementation(newImpl);
    }

    function getContractState(address proxy_) public view returns (ContractState memory state_) {
        NodeRegistry nodeRegistry = NodeRegistry(proxy_);
        state_.parameterRegistry = nodeRegistry.parameterRegistry();
        state_.canonicalNodesCount = nodeRegistry.canonicalNodesCount();
        state_.nodeCount = nodeRegistry.getAllNodesCount();
    }

    function isContractStateEqual(
        ContractState memory before_,
        ContractState memory after_
    ) public pure returns (bool isEqual_) {
        isEqual_ =
            before_.parameterRegistry == after_.parameterRegistry &&
            before_.canonicalNodesCount == after_.canonicalNodesCount &&
            before_.nodeCount == after_.nodeCount;
    }

    function _logContractState(string memory title_, ContractState memory state_) internal view {
        console.log(title_);
        console.log("  Parameter registry: %s", state_.parameterRegistry);
        console.log("  Canonical nodes count: %u", uint256(state_.canonicalNodesCount));
        console.log("  Node count: %u", uint256(state_.nodeCount));
    }

    function _writeNodeRegistryImplementation(address newImpl_) internal {
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        vm.serializeJson("root", vm.readFile(filePath_));
        string memory json_ = vm.serializeAddress("root", "nodeRegistryImplementation", newImpl_);
        vm.writeJson(json_, filePath_);
    }
}
