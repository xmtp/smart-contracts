// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";

import { RateRegistry } from "../src/settlement-chain/RateRegistry.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library RateRegistryDeployer {
    error ZeroFactory();
    error ZeroImplementation();

    function deployImplementation(
        address factory_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());

        constructorArguments_ = "";

        bytes memory creationCode_ = abi.encodePacked(type(RateRegistry).creationCode, constructorArguments_);

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_,
        address admin_
    ) internal returns (address proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_) {
        require(factory_ != address(0), ZeroFactory());
        require(implementation_ != address(0), ZeroImplementation());

        constructorArguments_ = abi.encode(IFactory(factory_).initializableImplementation());
        initializeCallData_ = abi.encodeCall(RateRegistry.initialize, (admin_));
        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }
}

contract DeployRateRegistry is Script {
    error PrivateKeyNotSet();
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error AdminNotSet();

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
        require(Environment.RATE_REGISTRY_IMPLEMENTATION != address(0), ImplementationNotSet());
        require(Environment.FACTORY != address(0), FactoryNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = RateRegistryDeployer.deployImplementation(
            Environment.FACTORY
        );

        require(implementation_ == Environment.RATE_REGISTRY_IMPLEMENTATION, UnexpectedImplementation());

        vm.stopBroadcast();

        string memory json_ = Utils.buildImplementationJson(
            Environment.FACTORY,
            implementation_,
            constructorArguments_
        );

        Utils.writeOutput(
            json_,
            string.concat(Environment.RATE_REGISTRY_OUTPUT_JSON, "_implementation_", vm.toString(block.chainid))
        );
    }

    function deployProxy() public {
        require(Environment.RATE_REGISTRY_PROXY != address(0), ProxyNotSet());
        require(Environment.FACTORY != address(0), FactoryNotSet());
        require(Environment.RATE_REGISTRY_IMPLEMENTATION != address(0), ImplementationNotSet());
        require(Environment.RATE_REGISTRY_ADMIN != address(0), AdminNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = RateRegistryDeployer.deployProxy(
            Environment.FACTORY,
            Environment.RATE_REGISTRY_IMPLEMENTATION,
            Environment.RATE_REGISTRY_SALT,
            Environment.RATE_REGISTRY_ADMIN
        );

        require(proxy_ == Environment.RATE_REGISTRY_PROXY, UnexpectedProxy());

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(Environment.FACTORY, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Environment.RATE_REGISTRY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }
}
