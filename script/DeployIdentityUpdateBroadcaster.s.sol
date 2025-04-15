// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
import { IPayloadBroadcaster } from "../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { IdentityUpdateBroadcaster } from "../src/app-chain/IdentityUpdateBroadcaster.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library IdentityUpdateBroadcasterDeployer {
    error ZeroFactory();
    error ZeroParameterRegistry();
    error ZeroImplementation();

    function deployImplementation(
        address factory_,
        address parameterRegistry_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());
        require(parameterRegistry_ != address(0), ZeroParameterRegistry());

        constructorArguments_ = abi.encode(parameterRegistry_);

        bytes memory creationCode_ = abi.encodePacked(
            type(IdentityUpdateBroadcaster).creationCode,
            constructorArguments_
        );

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_
    ) internal returns (address proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_) {
        require(factory_ != address(0), ZeroFactory());
        require(implementation_ != address(0), ZeroImplementation());

        constructorArguments_ = abi.encode(IFactory(factory_).initializableImplementation());
        initializeCallData_ = abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector);
        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }
}

contract DeployIdentityUpdateBroadcaster is Script {
    error PrivateKeyNotSet();
    error ImplementationNotSet();
    error ProxyNotSet();
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
        require(Environment.IDENTITY_UPDATE_BROADCASTER_IMPLEMENTATION != address(0), ImplementationNotSet());
        require(Environment.FACTORY != address(0), FactoryNotSet());
        require(Environment.PARAMETER_REGISTRY_PROXY != address(0), ParameterRegistryProxyNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = IdentityUpdateBroadcasterDeployer
            .deployImplementation(Environment.FACTORY, Environment.PARAMETER_REGISTRY_PROXY);

        require(implementation_ == Environment.IDENTITY_UPDATE_BROADCASTER_IMPLEMENTATION, UnexpectedImplementation());

        require(
            IdentityUpdateBroadcaster(implementation_).parameterRegistry() == Environment.PARAMETER_REGISTRY_PROXY,
            UnexpectedImplementation()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildImplementationJson(
            Environment.FACTORY,
            implementation_,
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(
                Environment.IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON,
                "_implementation_",
                vm.toString(block.chainid)
            )
        );
    }

    function deployProxy() public {
        require(Environment.IDENTITY_UPDATE_BROADCASTER_PROXY != address(0), ProxyNotSet());
        require(Environment.FACTORY != address(0), FactoryNotSet());
        require(Environment.IDENTITY_UPDATE_BROADCASTER_IMPLEMENTATION != address(0), ImplementationNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            Environment.FACTORY,
            Environment.IDENTITY_UPDATE_BROADCASTER_IMPLEMENTATION,
            Environment.IDENTITY_UPDATE_BROADCASTER_PROXY_SALT
        );

        require(proxy_ == Environment.IDENTITY_UPDATE_BROADCASTER_PROXY, UnexpectedProxy());

        require(
            IdentityUpdateBroadcaster(proxy_).implementation() ==
                Environment.IDENTITY_UPDATE_BROADCASTER_IMPLEMENTATION,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(Environment.FACTORY, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Environment.IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }
}
