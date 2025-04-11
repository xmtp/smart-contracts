// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";

import { NodeRegistry } from "../src/settlement-chain/NodeRegistry.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library NodeRegistryDeployer {
    function deployImplementation(
        address factory_,
        address initialAdmin_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        constructorArguments_ = abi.encode(initialAdmin_);

        bytes memory creationCode_ = abi.encodePacked(type(NodeRegistry).creationCode, constructorArguments_);

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }
}

contract DeployNodeRegistry is Script {
    error PrivateKeyNotSet();
    error ExpectedImplementationNotSet();
    error UnexpectedImplementation();

    uint256 internal _privateKey;
    address internal _deployer;

    function setUp() external {
        _privateKey = vm.envUint("PRIVATE_KEY");

        require(_privateKey != 0, PrivateKeyNotSet());

        _deployer = vm.addr(_privateKey);
    }

    function run() external {
        deployImplementation();
    }

    function deployImplementation() public {
        require(Environment.EXPECTED_NODE_REGISTRY_IMPLEMENTATION != address(0), ExpectedImplementationNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = NodeRegistryDeployer.deployImplementation(
            Environment.EXPECTED_FACTORY,
            Environment.NODE_REGISTRY_ADMIN
        );

        require(implementation_ == Environment.EXPECTED_NODE_REGISTRY_IMPLEMENTATION, UnexpectedImplementation());

        require(NodeRegistry(implementation_).owner() == Environment.NODE_REGISTRY_ADMIN, UnexpectedImplementation());

        vm.stopBroadcast();

        string memory json_ = Utils.buildImplementationJson(
            Environment.EXPECTED_FACTORY,
            implementation_,
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(Environment.NODE_REGISTRY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }
}
