// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
import { IPayloadBroadcaster } from "../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { GroupMessageBroadcaster } from "../src/app-chain/GroupMessageBroadcaster.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library GroupMessageBroadcasterDeployer {
    function deployImplementation(
        address factory_,
        address registry_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        constructorArguments_ = abi.encode(registry_);

        bytes memory creationCode_ = abi.encodePacked(
            type(GroupMessageBroadcaster).creationCode,
            constructorArguments_
        );

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_
    )
        internal
        returns (GroupMessageBroadcaster proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_)
    {
        constructorArguments_ = abi.encode(IFactory(factory_).initializableImplementation());
        initializeCallData_ = abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector);
        proxy_ = GroupMessageBroadcaster(IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_));
    }
}

contract DeployGroupMessageBroadcaster is Script {
    error PrivateKeyNotSet();
    error ExpectedImplementationNotSet();
    error ExpectedProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();

    uint256 internal _privateKey;
    address internal _deployer;

    function setUp() external {
        _privateKey = vm.envUint("PRIVATE_KEY");

        require(_privateKey != 0, PrivateKeyNotSet());

        _deployer = vm.addr(_privateKey);
    }

    function run() external {
        deployImplementation();
        deployProxy();
    }

    function deployImplementation() public {
        require(
            Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_IMPLEMENTATION != address(0),
            ExpectedImplementationNotSet()
        );

        require(Environment.EXPECTED_FACTORY != address(0), FactoryNotSet());
        require(Environment.EXPECTED_PARAMETER_REGISTRY_PROXY != address(0), ParameterRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = GroupMessageBroadcasterDeployer
            .deployImplementation(Environment.EXPECTED_FACTORY, Environment.EXPECTED_PARAMETER_REGISTRY_PROXY);

        require(
            implementation_ == Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_IMPLEMENTATION,
            UnexpectedImplementation()
        );

        require(
            GroupMessageBroadcaster(implementation_).registry() == Environment.EXPECTED_PARAMETER_REGISTRY_PROXY,
            UnexpectedImplementation()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildImplementationJson(
            Environment.EXPECTED_FACTORY,
            implementation_,
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(
                Environment.GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON,
                "_implementation_",
                vm.toString(block.chainid)
            )
        );
    }

    function deployProxy() public {
        require(Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_PROXY != address(0), ExpectedProxyNotSet());
        require(Environment.EXPECTED_FACTORY != address(0), FactoryNotSet());

        require(
            Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_IMPLEMENTATION != address(0),
            ExpectedImplementationNotSet()
        );

        vm.startBroadcast(_privateKey);

        (GroupMessageBroadcaster proxy_, bytes memory constructorArguments_, ) = GroupMessageBroadcasterDeployer
            .deployProxy(
                Environment.EXPECTED_FACTORY,
                Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_IMPLEMENTATION,
                Environment.GROUP_MESSAGE_BROADCASTER_PROXY_SALT
            );

        require(address(proxy_) == Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_PROXY, UnexpectedProxy());

        require(
            proxy_.implementation() == Environment.EXPECTED_GROUP_MESSAGE_BROADCASTER_IMPLEMENTATION,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(
            Environment.EXPECTED_FACTORY,
            _deployer,
            address(proxy_),
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(Environment.GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }
}
