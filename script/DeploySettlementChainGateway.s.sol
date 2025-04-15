// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";

import { SettlementChainGateway } from "../src/settlement-chain/SettlementChainGateway.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library SettlementChainGatewayDeployer {
    error ZeroFactory();
    error ZeroParameterRegistry();
    error ZeroAppChainGateway();
    error ZeroAppChainNativeToken();
    error ZeroImplementation();
    function deployImplementation(
        address factory_,
        address parameterRegistry_,
        address appChainGateway_,
        address appChainNativeToken_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());
        require(parameterRegistry_ != address(0), ZeroParameterRegistry());
        require(appChainGateway_ != address(0), ZeroAppChainGateway());
        require(appChainNativeToken_ != address(0), ZeroAppChainNativeToken());

        constructorArguments_ = abi.encode(parameterRegistry_, appChainGateway_, appChainNativeToken_);

        bytes memory creationCode_ = abi.encodePacked(type(SettlementChainGateway).creationCode, constructorArguments_);

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
        initializeCallData_ = abi.encodeWithSelector(SettlementChainGateway.initialize.selector);
        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }
}

contract DeploySettlementChainGateway is Script {
    error PrivateKeyNotSet();
    error ImplementationNotSet();
    error ProxyNotSet();
    error UnexpectedImplementation();
    error UnexpectedProxy();
    error FactoryNotSet();
    error ParameterRegistryProxyNotSet();
    error GatewayProxyNotSet();
    error AppChainNativeTokenNotSet();

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
        require(Environment.SETTLEMENT_CHAIN_GATEWAY_IMPLEMENTATION != address(0), ImplementationNotSet());
        require(Environment.FACTORY != address(0), FactoryNotSet());
        require(Environment.PARAMETER_REGISTRY_PROXY != address(0), ParameterRegistryProxyNotSet());
        require(Environment.GATEWAY_PROXY != address(0), GatewayProxyNotSet());
        require(Environment.APP_CHAIN_NATIVE_TOKEN != address(0), AppChainNativeTokenNotSet());

        vm.startBroadcast(_privateKey);

        (address implementation_, bytes memory constructorArguments_) = SettlementChainGatewayDeployer
            .deployImplementation(
                Environment.FACTORY,
                Environment.PARAMETER_REGISTRY_PROXY,
                Environment.GATEWAY_PROXY,
                Environment.APP_CHAIN_NATIVE_TOKEN
            );

        require(implementation_ == Environment.SETTLEMENT_CHAIN_GATEWAY_IMPLEMENTATION, UnexpectedImplementation());

        require(
            SettlementChainGateway(implementation_).parameterRegistry() == Environment.PARAMETER_REGISTRY_PROXY,
            UnexpectedImplementation()
        );

        require(
            SettlementChainGateway(implementation_).appChainGateway() == Environment.GATEWAY_PROXY,
            UnexpectedImplementation()
        );

        require(
            SettlementChainGateway(implementation_).appChainNativeToken() == Environment.APP_CHAIN_NATIVE_TOKEN,
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
                Environment.SETTLEMENT_CHAIN_GATEWAY_OUTPUT_JSON,
                "_implementation_",
                vm.toString(block.chainid)
            )
        );
    }

    function deployProxy() public {
        require(Environment.GATEWAY_PROXY != address(0), ProxyNotSet());
        require(Environment.FACTORY != address(0), FactoryNotSet());
        require(Environment.SETTLEMENT_CHAIN_GATEWAY_IMPLEMENTATION != address(0), ImplementationNotSet());

        vm.startBroadcast(_privateKey);

        (address proxy_, bytes memory constructorArguments_, ) = SettlementChainGatewayDeployer.deployProxy(
            Environment.FACTORY,
            Environment.SETTLEMENT_CHAIN_GATEWAY_IMPLEMENTATION,
            Environment.GATEWAY_PROXY_SALT
        );

        require(proxy_ == Environment.GATEWAY_PROXY, UnexpectedProxy());

        require(
            SettlementChainGateway(proxy_).implementation() == Environment.SETTLEMENT_CHAIN_GATEWAY_IMPLEMENTATION,
            UnexpectedProxy()
        );

        vm.stopBroadcast();

        string memory json_ = Utils.buildProxyJson(Environment.FACTORY, _deployer, proxy_, constructorArguments_);

        Utils.writeOutput(
            json_,
            string.concat(Environment.SETTLEMENT_CHAIN_GATEWAY_OUTPUT_JSON, "_proxy_", vm.toString(block.chainid))
        );
    }
}
