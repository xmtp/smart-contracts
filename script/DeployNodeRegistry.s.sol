// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CREATE3Factory } from "../src/CREATE3Factory.sol";

import { NodeRegistry } from "../src/NodeRegistry.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

contract DeployNodeRegistry is Utils, Environment {
    uint256 private _privateKey;

    CREATE3Factory public factory;

    bytes32 public constant SALT = keccak256("NodeRegistry");

    address public admin;
    address public deployer;
    address public nodeRegistry;

    function run() public {
        _setup();

        vm.startBroadcast(_privateKey);

        address predictedAddress = factory.predictDeterministicAddress(SALT, deployer);

        require(predictedAddress != address(0), "NodeRegistry predicted address is zero");
        require(predictedAddress.code.length == 0, "NodeRegistry predicted address has code");

        bytes memory initCode = abi.encodePacked(type(NodeRegistry).creationCode, abi.encode(admin));

        nodeRegistry = factory.deploy(SALT, initCode);
        require(predictedAddress == nodeRegistry, "NodeRegistry deployed address doesn't match predicted address");

        vm.stopBroadcast();

        _serializeDeploymentData();
    }

    function _setup() internal {
        admin = vm.envAddress("XMTP_NODE_REGISTRY_ADMIN_ADDRESS");
        require(admin != address(0), "XMTP_NODE_REGISTRY_ADMIN_ADDRESS not set");

        address create3Factory = vm.envAddress("XMTP_CREATE3_FACTORY_ADDRESS");
        require(create3Factory != address(0), "XMTP_CREATE3_FACTORY_ADDRESS not set");

        _privateKey = vm.envUint("PRIVATE_KEY");
        require(_privateKey != 0, "PRIVATE_KEY not set");

        deployer = vm.addr(_privateKey);
        factory = CREATE3Factory(create3Factory);
    }

    function _serializeDeploymentData() internal {
        string memory parent_object = "parent object";
        string memory addresses = "addresses";
        string memory constructorArgs = "constructorArgs";

        string memory addressesOutput;
        addressesOutput = vm.serializeAddress(addresses, "deployer", deployer);
        addressesOutput = vm.serializeAddress(addresses, "implementation", nodeRegistry);

        string memory constructorArgsOutput = vm.serializeAddress(constructorArgs, "initialAdmin", admin);

        string memory finalJson;
        finalJson = vm.serializeString(parent_object, addresses, addressesOutput);
        finalJson = vm.serializeString(parent_object, constructorArgs, constructorArgsOutput);
        finalJson = vm.serializeUint(parent_object, "deploymentBlock", block.number);

        writeOutput(finalJson, XMTP_NODE_REGISTRY_OUTPUT_JSON);
    }
}
