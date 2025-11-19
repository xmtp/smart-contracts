// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";
import { GenericEIP1967Migrator } from "../../src/any-chain/GenericEIP1967Migrator.sol";
import { NodeRegistry } from "../../src/settlement-chain/NodeRegistry.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { Utils } from "../utils/Utils.sol";
import { NodeRegistryDeployer } from "../deployers/NodeRegistryDeployer.sol";

/**
 * @notice Upgrades the NodeRegistry proxy to a new implementation
 * @dev This script:
 *      - Reads addresses for: factory, parameter registry and node registry proxy from config JSON file
 *      - Deploys a new NodeRegistry implementation via the Factory
 *      - Creates a GenericEIP1967Migrator with the new implementation
 *      - Sets the migrator address in the Parameter Registry
 *      - Executes the migration on the proxy
 *      - Compares the state before and after upgrade
 * Usage:
 *   ENVIRONMENT=testnet-dev \
 *   ADMIN_PRIVATE_KEY=0x... \
 *   forge script script/upgrades/NodeRegistryUpgrader.s.sol:NodeRegistryUpgrader \
 *     --sig "UpgradeNodeRegistry()" \
 *     --rpc-url base_sepolia  \
 *     --broadcast \
 *     --slow
 */
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
    Utils.DeploymentData internal _deployment;
    ContractState internal _contractStateBefore;

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

        // Contract state before upgrade
        address proxy = _deployment.nodeRegistryProxy;
        _contractStateBefore = getContractState(proxy);
    }

    function UpgradeNodeRegistry() external {
        address factory = _deployment.factory;
        console.log("factory %s", factory);
        address paramRegistry = _deployment.parameterRegistryProxy;
        console.log("paramRegistry %s", paramRegistry);
        address proxy = _deployment.nodeRegistryProxy;
        console.log("proxy %s", proxy);

        vm.startBroadcast(_privateKey);

        // Compute implementation address
        address computedImpl = NodeRegistryDeployer.getImplementation(factory, paramRegistry);
        address newImpl;

        // Skip deploymwnt if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            newImpl = computedImpl;
        } else {
            // Deploy new implementation, can be called by ANY address
            (newImpl, ) = NodeRegistryDeployer.deployImplementation(factory, paramRegistry);
        }
        console.log("newImpl %s", newImpl);

        // Deploy generic migrator, can be called by ANY address
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator (also param reg migrator value) %s", address(migrator));

        // Parameter registry stores the migrator address, must be called by a param registry admin address
        string memory key = NodeRegistry(proxy).migratorParameterKey();
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));
        console.log("param reg migrator key %s", key);

        // Perform migration, can be called by any address
        NodeRegistry(proxy).migrate();
        vm.stopBroadcast();

        // Compare state before and after upgrade
        ContractState memory contractStateAfter = getContractState(proxy);
        _logContractState("State before upgrade:", _contractStateBefore);
        _logContractState("State after upgrade:", contractStateAfter);
        if (!isContractStateEqual(_contractStateBefore, contractStateAfter)) revert StateMismatch();
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
        console.log("%s", title_);
        console.log("  Parameter registry: %s", state_.parameterRegistry);
        console.log("  Canonical nodes count: %u", uint256(state_.canonicalNodesCount));
        console.log("  Node count: %u", uint256(state_.nodeCount));
    }
}
