// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { AppChainGatewayDeployer } from "./deployers/AppChainGatewayDeployer.sol";
import { AppChainParameterRegistryDeployer } from "./deployers/AppChainParameterRegistryDeployer.sol";
import { DepositSplitterDeployer } from "./deployers/DepositSplitterDeployer.sol";
import { DistributionManagerDeployer } from "./deployers/DistributionManagerDeployer.sol";
import { FactoryDeployer } from "./deployers/FactoryDeployer.sol";
import { FeeTokenDeployer } from "./deployers/FeeTokenDeployer.sol";
import { GroupMessageBroadcasterDeployer } from "./deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "./deployers/IdentityUpdateBroadcasterDeployer.sol";
import { MockUnderlyingFeeTokenDeployer } from "./deployers/MockUnderlyingFeeTokenDeployer.sol";
import { NodeRegistryDeployer } from "./deployers/NodeRegistryDeployer.sol";
import { PayerRegistryDeployer } from "./deployers/PayerRegistryDeployer.sol";
import { PayerReportManagerDeployer } from "./deployers/PayerReportManagerDeployer.sol";
import { RateRegistryDeployer } from "./deployers/RateRegistryDeployer.sol";
import { SettlementChainGatewayDeployer } from "./deployers/SettlementChainGatewayDeployer.sol";
import { SettlementChainParameterRegistryDeployer } from "./deployers/SettlementChainParameterRegistryDeployer.sol";

import { AddressAliasHelper } from "../src/libraries/AddressAliasHelper.sol";

import { IAppChainGateway } from "../src/app-chain/interfaces/IAppChainGateway.sol";
import { IAppChainParameterRegistry } from "../src/app-chain/interfaces/IAppChainParameterRegistry.sol";
import { IDepositSplitter } from "../src/settlement-chain/interfaces/IDepositSplitter.sol";
import { IDistributionManager } from "../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
import { IFeeToken } from "../src/settlement-chain/interfaces/IFeeToken.sol";
import { IGroupMessageBroadcaster } from "../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { INodeRegistry } from "../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../src/settlement-chain/interfaces/IRateRegistry.sol";
import { ISettlementChainGateway } from "../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import {
    ISettlementChainParameterRegistry
} from "../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

import { Utils } from "./utils/Utils.sol";

import { MockUnderlyingFeeToken } from "../test/utils/Mocks.sol";

contract DeployScripts is Script {
    error AppChainIdNotSet();
    error DeployerNotSet();
    error EnvironmentContainsAppChainData();
    error EnvironmentContainsSettlementChainData();
    error EnvironmentContainsUnexpectedDeployer();
    error EnvironmentNotSet();
    error FactoryNotSet();
    error FeeTokenProxyNotSet();
    error GatewayProxyNotSet();
    error ImplementationNotSet();
    error InitializableImplementationNotSet();
    error NodeRegistryProxyNotSet();
    error ParameterRegistryProxyNotSet();
    error PayerRegistryProxyNotSet();
    error PayerReportManagerProxyNotSet();
    error PrivateKeyNotSet();
    error ProxyNotSet();
    error ProxySaltNotSet();
    error UnderlyingFeeTokenNotSet();
    error UnexpectedChainId();
    error UnexpectedDeployer();
    error UnexpectedFactory();
    error UnexpectedImplementation(address expected, address actual);
    error UnexpectedProxy(address expected, address actual);
    error ProxyExistsWithDifferentImplementation(
        address proxy,
        address expectedImplementation,
        address actualImplementation
    );

    Utils.DeploymentData internal _deploymentData;

    bool internal _isInGatewayTestingMode;

    string internal _environment;

    uint256 internal _privateKey;
    address internal _deployer;

    function setUp() external {
        _isInGatewayTestingMode = vm.envOr("IS_GATEWAY_TESTING", false);

        _environment = vm.envString("ENVIRONMENT");

        if (bytes(_environment).length == 0) revert EnvironmentNotSet();

        console.log("Environment: %s", _environment);

        _deploymentData = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        if (_deploymentData.deployer == address(0)) revert DeployerNotSet();

        _privateKey = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));

        if (_privateKey == 0) revert PrivateKeyNotSet();

        address deployer_ = vm.envAddress("DEPLOYER");

        if (deployer_ == address(0)) revert DeployerNotSet();

        _deployer = vm.addr(_privateKey);

        console.log("Deployer: %s", _deployer);

        if (_deployer != _deploymentData.deployer) revert UnexpectedDeployer();
        if (_deployer != deployer_) revert UnexpectedDeployer();
    }

    /* ============ Main Entrypoints ============ */

    function deployBaseSettlementChainComponents() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        // NOTE: Deploy the factory proxy first, so that the first address deployed by the deployer is the "factory".
        deployFactoryProxy();
        deployFactoryImplementation();
        initializeFactory();
        deploySettlementChainParameterRegistryImplementation();
        deploySettlementChainParameterRegistryProxy();
        deployMockUnderlyingFeeTokenImplementation();
        deployMockUnderlyingFeeTokenProxy();
        deployFeeTokenImplementation();
        deployFeeTokenProxy();
        deploySettlementChainGatewayImplementation();
        deploySettlementChainGatewayProxy();
    }

    function deployAllSettlementChainComponentImplementations() external {
        deployFactoryImplementationViaFactory();
        deploySettlementChainParameterRegistryImplementation();
        deployMockUnderlyingFeeTokenImplementation();
        deployFeeTokenImplementation();
        deploySettlementChainGatewayImplementation();

        deploySettlementChainComponentImplementations();
    }

    function deploySettlementChainComponents() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        uint256 blockNumber_ = block.number;

        deploySettlementChainComponentImplementations();
        deploySettlementChainComponentProxies();

        _writeSettlementChainData(blockNumber_);
    }

    function deploySettlementChainComponentImplementations() public {
        deployPayerRegistryImplementation();
        deployRateRegistryImplementation();
        deployNodeRegistryImplementation();
        deployPayerReportManagerImplementation();
        deployDistributionManagerImplementation();
        deployDepositSplitter();
    }

    function deploySettlementChainComponentProxies() public {
        deployPayerRegistryProxy();
        deployRateRegistryProxy();
        deployNodeRegistryProxy();
        deployPayerReportManagerProxy();
        deployDistributionManagerProxy();
    }

    function deployBaseAppChainComponents() external {
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        // NOTE: Deploy the factory proxy first, so that the first address deployed by the deployer is the "factory".
        deployFactoryProxy();
        deployFactoryImplementation();
        initializeFactory();
        deployAppChainParameterRegistryImplementation();
        deployAppChainParameterRegistryProxy();
        deployAppChainGatewayImplementation();
        deployAppChainGatewayProxy();
    }

    function deployAllAppChainComponentImplementations() external {
        deployFactoryImplementationViaFactory();
        deployAppChainParameterRegistryImplementation();
        deployAppChainGatewayImplementation();

        deployAppChainComponentImplementations();
    }

    function deployAppChainComponents() external {
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        uint256 blockNumber_ = block.number;

        deployAppChainComponentImplementations();
        deployAppChainComponentProxies();

        _writeAppChainData(blockNumber_);
    }

    function deployAppChainComponentImplementations() public {
        deployGroupMessageBroadcasterImplementation();
        deployIdentityUpdateBroadcasterImplementation();
    }

    function deployAppChainComponentProxies() public {
        deployGroupMessageBroadcasterProxy();
        deployIdentityUpdateBroadcasterProxy();
    }

    function checkSettlementChainComponents() external view {
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        string memory json_ = vm.readFile(filePath_);

        // TODO: For some or all of these, check a getter to ensure the contracts are as expected.

        if (vm.parseJsonUint(json_, ".settlementChainId") != block.chainid) revert("Settlement chain ID mismatch");

        if (vm.parseJsonAddress(json_, ".settlementChainFactory").code.length == 0) {
            revert("Settlement chain factory does not exist");
        }

        if (vm.parseJsonAddress(json_, ".underlyingFeeToken").code.length == 0) {
            revert("Underlying fee token does not exist");
        }

        if (vm.parseJsonAddress(json_, ".feeToken").code.length == 0) {
            revert("Fee token does not exist");
        }

        if (vm.parseJsonAddress(json_, ".settlementChainParameterRegistry").code.length == 0) {
            revert("Settlement chain parameter registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".settlementChainGateway").code.length == 0) {
            revert("Settlement chain gateway does not exist");
        }

        if (vm.parseJsonAddress(json_, ".payerRegistry").code.length == 0) {
            revert("Payer registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".rateRegistry").code.length == 0) {
            revert("Rate registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".nodeRegistry").code.length == 0) {
            revert("Node registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".payerReportManager").code.length == 0) {
            revert("Payer report manager does not exist");
        }

        if (vm.parseJsonAddress(json_, ".distributionManager").code.length == 0) {
            revert("Distribution manager does not exist");
        }

        if (vm.parseJsonAddress(json_, ".depositSplitter").code.length == 0) {
            revert("Deposit splitter does not exist");
        }
    }

    function checkAppChainComponents() external view {
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        string memory json_ = vm.readFile(filePath_);

        // TODO: For some or all of these, check a getter to ensure the contracts are as expected.

        if (vm.parseJsonUint(json_, ".appChainId") != block.chainid) revert("App chain ID mismatch");

        if (vm.parseJsonAddress(json_, ".appChainFactory").code.length == 0) {
            revert("App chain factory does not exist");
        }

        if (vm.parseJsonAddress(json_, ".appChainParameterRegistry").code.length == 0) {
            revert("App chain parameter registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".appChainGateway").code.length == 0) {
            revert("App chain gateway does not exist");
        }

        if (vm.parseJsonAddress(json_, ".groupMessageBroadcaster").code.length == 0) {
            revert("Group message broadcaster does not exist");
        }

        if (vm.parseJsonAddress(json_, ".identityUpdateBroadcaster").code.length == 0) {
            revert("Identity update broadcaster does not exist");
        }
    }

    /* ============ Individual Deployers ============ */

    function deployFactoryImplementation() public {
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();

        address implementation_ = _deploymentData.factoryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = FactoryDeployer.deployImplementation(_deploymentData.parameterRegistryProxy);

            vm.stopBroadcast();

            console.log("Factory Implementation Name: %s", IFactory(implementation_).contractName());
            console.log("Factory Implementation Version: %s", IFactory(implementation_).version());
            console.log("Factory Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.factoryImplementation) {
            revert UnexpectedImplementation(_deploymentData.factoryImplementation, implementation_);
        }

        if (IFactory(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IFactory(implementation_).parameterRegistry()
            );
        }
    }

    function deployFactoryImplementationViaFactory() public {
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = _deploymentData.factoryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = FactoryDeployer.deployImplementationViaFactory(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("Factory Implementation Name: %s", IFactory(implementation_).contractName());
            console.log("Factory Implementation Version: %s", IFactory(implementation_).version());
            console.log("Factory Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.factoryImplementation) {
            revert UnexpectedImplementation(_deploymentData.factoryImplementation, implementation_);
        }

        if (IFactory(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IFactory(implementation_).parameterRegistry()
            );
        }
    }

    function deployFactoryProxy() public {
        if (_deploymentData.factory == address(0)) revert ProxyNotSet();
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();

        address proxy_ = _deploymentData.factory;

        if (proxy_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (proxy_, , ) = FactoryDeployer.deployProxy(_deploymentData.factoryImplementation);

            vm.stopBroadcast();

            console.log("Factory Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.factory) revert UnexpectedProxy(_deploymentData.factory, proxy_);

        // NOTE: The factory implementation may not yet be deployed, so `factory_.implementation()` may revert.
    }

    function initializeFactory() public {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.initializableImplementation == address(0)) revert InitializableImplementationNotSet();

        // If `initializableImplementation` is nonzero, the factory is already deployed it in a previous initialization.
        if (IFactory(_deploymentData.factory).initializableImplementation() == address(0)) {
            vm.startBroadcast(_privateKey);

            IFactory(_deploymentData.factory).initialize();

            vm.stopBroadcast();

            console.log("Factory Initialized");
        }

        if (IFactory(_deploymentData.factory).implementation() != _deploymentData.factoryImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.factoryImplementation,
                IFactory(_deploymentData.factory).implementation()
            );
        }

        if (
            IFactory(_deploymentData.factory).initializableImplementation() !=
            _deploymentData.initializableImplementation
        ) {
            revert UnexpectedImplementation(
                _deploymentData.initializableImplementation,
                IFactory(_deploymentData.factory).initializableImplementation()
            );
        }
    }

    function deploySettlementChainParameterRegistryImplementation() public {
        if (_deploymentData.settlementChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        address implementation_ = _deploymentData.settlementChainParameterRegistryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(
                _deploymentData.factory
            );

            vm.stopBroadcast();

            console.log(
                "SettlementChainParameterRegistry Implementation Name: %s",
                ISettlementChainParameterRegistry(implementation_).contractName()
            );
            console.log(
                "SettlementChainParameterRegistry Implementation Version: %s",
                ISettlementChainParameterRegistry(implementation_).version()
            );
            console.log("SettlementChainParameterRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.settlementChainParameterRegistryImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.settlementChainParameterRegistryImplementation,
                implementation_
            );
        }
    }

    function deploySettlementChainParameterRegistryProxy() public {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.settlementChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.parameterRegistryProxySalt == 0) revert ProxySaltNotSet();

        address[] memory admins_ = _getAdmins();

        address proxy_ = _deploymentData.parameterRegistryProxy;

        if (proxy_.code.length == 0) {
            console.log(
                "SettlementChainParameterRegistry Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.parameterRegistryProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.settlementChainParameterRegistryImplementation,
                _deploymentData.parameterRegistryProxySalt,
                admins_
            );

            vm.stopBroadcast();

            console.log("SettlementChainParameterRegistry Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedProxy(_deploymentData.parameterRegistryProxy, proxy_);
        }

        if (
            ISettlementChainParameterRegistry(proxy_).implementation() !=
            _deploymentData.settlementChainParameterRegistryImplementation
        ) {
            revert UnexpectedImplementation(
                _deploymentData.settlementChainParameterRegistryImplementation,
                ISettlementChainParameterRegistry(proxy_).implementation()
            );
        }

        for (uint256 index_; index_ < admins_.length; ++index_) {
            if (!ISettlementChainParameterRegistry(proxy_).isAdmin(admins_[index_])) {
                revert UnexpectedProxy(admins_[index_], address(0));
            }
        }
    }

    function deployMockUnderlyingFeeTokenImplementation() public {
        if (_isInGatewayTestingMode) return;

        // Skip deployment if the mock underlying fee token implementation is not set.
        if (_deploymentData.mockUnderlyingFeeTokenImplementation == address(0)) return;

        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = _deploymentData.mockUnderlyingFeeTokenImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = MockUnderlyingFeeTokenDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("MockUnderlyingFeeToken Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.mockUnderlyingFeeTokenImplementation) {
            revert UnexpectedImplementation(_deploymentData.mockUnderlyingFeeTokenImplementation, implementation_);
        }

        if (MockUnderlyingFeeToken(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                MockUnderlyingFeeToken(implementation_).parameterRegistry()
            );
        }
    }

    function deployMockUnderlyingFeeTokenProxy() public {
        if (_isInGatewayTestingMode) return;

        // Skip deployment if the mock underlying fee token implementation is not set.
        if (_deploymentData.mockUnderlyingFeeTokenImplementation == address(0)) return;

        if (_deploymentData.underlyingFeeToken == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.mockUnderlyingFeeTokenProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.underlyingFeeToken;

        if (proxy_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (proxy_, , ) = MockUnderlyingFeeTokenDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.mockUnderlyingFeeTokenImplementation,
                _deploymentData.mockUnderlyingFeeTokenProxySalt
            );

            vm.stopBroadcast();

            console.log("MockUnderlyingFeeToken Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.underlyingFeeToken) {
            revert UnexpectedProxy(_deploymentData.underlyingFeeToken, proxy_);
        }

        if (MockUnderlyingFeeToken(proxy_).implementation() != _deploymentData.mockUnderlyingFeeTokenImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.mockUnderlyingFeeTokenImplementation,
                MockUnderlyingFeeToken(proxy_).implementation()
            );
        }
    }

    function deployFeeTokenImplementation() public {
        if (_isInGatewayTestingMode) return;

        if (_deploymentData.feeTokenImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.underlyingFeeToken == address(0)) revert UnderlyingFeeTokenNotSet();

        address implementation_ = _deploymentData.feeTokenImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = FeeTokenDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.underlyingFeeToken
            );

            vm.stopBroadcast();

            console.log("FeeToken Implementation Name: %s", IFeeToken(implementation_).contractName());
            console.log("FeeToken Implementation Version: %s", IFeeToken(implementation_).version());
            console.log("FeeToken Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.feeTokenImplementation) {
            revert UnexpectedImplementation(_deploymentData.feeTokenImplementation, implementation_);
        }

        if (IFeeToken(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IFeeToken(implementation_).parameterRegistry()
            );
        }

        if (IFeeToken(implementation_).underlying() != _deploymentData.underlyingFeeToken) {
            revert UnexpectedImplementation(
                _deploymentData.underlyingFeeToken,
                IFeeToken(implementation_).underlying()
            );
        }
    }

    function deployFeeTokenProxy() public {
        if (_isInGatewayTestingMode) return;

        if (_deploymentData.feeTokenProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.feeTokenImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.feeTokenProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.feeTokenProxy;

        if (proxy_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (proxy_, , ) = FeeTokenDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.feeTokenImplementation,
                _deploymentData.feeTokenProxySalt
            );

            vm.stopBroadcast();

            console.log("FeeToken Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.feeTokenProxy) {
            revert UnexpectedProxy(_deploymentData.feeTokenProxy, proxy_);
        }

        if (IFeeToken(proxy_).implementation() != _deploymentData.feeTokenImplementation) {
            revert UnexpectedImplementation(_deploymentData.feeTokenImplementation, IFeeToken(proxy_).implementation());
        }
    }

    function deploySettlementChainGatewayImplementation() public {
        if (_deploymentData.settlementChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();

        address implementation_ = _deploymentData.settlementChainGatewayImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.gatewayProxy,
                _deploymentData.feeTokenProxy
            );

            vm.stopBroadcast();

            console.log(
                "SettlementChainGateway Implementation Name: %s",
                ISettlementChainGateway(implementation_).contractName()
            );
            console.log(
                "SettlementChainGateway Implementation Version: %s",
                ISettlementChainGateway(implementation_).version()
            );
            console.log("SettlementChainGateway Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.settlementChainGatewayImplementation) {
            revert UnexpectedImplementation(_deploymentData.settlementChainGatewayImplementation, implementation_);
        }

        if (ISettlementChainGateway(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                ISettlementChainGateway(implementation_).parameterRegistry()
            );
        }

        if (ISettlementChainGateway(implementation_).appChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation(
                _deploymentData.gatewayProxy,
                ISettlementChainGateway(implementation_).appChainGateway()
            );
        }

        if (ISettlementChainGateway(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation(
                _deploymentData.feeTokenProxy,
                ISettlementChainGateway(implementation_).feeToken()
            );
        }
    }

    function deploySettlementChainGatewayProxy() public {
        if (_deploymentData.gatewayProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.settlementChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.gatewayProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.gatewayProxy;

        if (proxy_.code.length == 0) {
            console.log(
                "SettlementChainGateway Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.gatewayProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.settlementChainGatewayImplementation,
                _deploymentData.gatewayProxySalt
            );

            vm.stopBroadcast();

            console.log("SettlementChainGateway Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.gatewayProxy) {
            revert UnexpectedProxy(_deploymentData.gatewayProxy, proxy_);
        }

        if (ISettlementChainGateway(proxy_).implementation() != _deploymentData.settlementChainGatewayImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.settlementChainGatewayImplementation,
                ISettlementChainGateway(proxy_).implementation()
            );
        }
    }

    function deployPayerRegistryImplementation() public {
        if (_deploymentData.payerRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();

        address implementation_ = _deploymentData.payerRegistryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = PayerRegistryDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.feeTokenProxy
            );

            vm.stopBroadcast();

            console.log("PayerRegistry Implementation Name: %s", IPayerRegistry(implementation_).contractName());
            console.log("PayerRegistry Implementation Version: %s", IPayerRegistry(implementation_).version());
            console.log("PayerRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.payerRegistryImplementation) {
            revert UnexpectedImplementation(_deploymentData.payerRegistryImplementation, implementation_);
        }

        if (IPayerRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IPayerRegistry(implementation_).parameterRegistry()
            );
        }

        if (IPayerRegistry(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation(_deploymentData.feeTokenProxy, IPayerRegistry(implementation_).feeToken());
        }
    }

    function deployPayerRegistryProxy() public {
        if (_deploymentData.payerRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.payerRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.payerRegistryProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.payerRegistryProxy;

        if (proxy_.code.length == 0) {
            console.log("PayerRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.payerRegistryProxySalt));

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = PayerRegistryDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.payerRegistryImplementation,
                _deploymentData.payerRegistryProxySalt
            );

            vm.stopBroadcast();

            console.log("PayerRegistry Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.payerRegistryProxy) {
            revert UnexpectedProxy(_deploymentData.payerRegistryProxy, proxy_);
        }

        if (IPayerRegistry(proxy_).implementation() != _deploymentData.payerRegistryImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.payerRegistryImplementation,
                IPayerRegistry(proxy_).implementation()
            );
        }
    }

    function deployRateRegistryImplementation() public {
        if (_deploymentData.rateRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = _deploymentData.rateRegistryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = RateRegistryDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("RateRegistry Implementation Name: %s", IRateRegistry(implementation_).contractName());
            console.log("RateRegistry Implementation Version: %s", IRateRegistry(implementation_).version());
            console.log("RateRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.rateRegistryImplementation) {
            revert UnexpectedImplementation(_deploymentData.rateRegistryImplementation, implementation_);
        }

        if (IRateRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IRateRegistry(implementation_).parameterRegistry()
            );
        }
    }

    function deployRateRegistryProxy() public {
        if (_deploymentData.rateRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.rateRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.rateRegistryProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.rateRegistryProxy;

        if (proxy_.code.length == 0) {
            console.log("RateRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.rateRegistryProxySalt));

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = RateRegistryDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.rateRegistryImplementation,
                _deploymentData.rateRegistryProxySalt
            );

            vm.stopBroadcast();

            console.log("RateRegistry Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.rateRegistryProxy) {
            revert UnexpectedProxy(_deploymentData.rateRegistryProxy, proxy_);
        }

        if (IRateRegistry(proxy_).implementation() != _deploymentData.rateRegistryImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.rateRegistryImplementation,
                IRateRegistry(proxy_).implementation()
            );
        }
    }

    function deployNodeRegistryImplementation() public {
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = _deploymentData.nodeRegistryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = NodeRegistryDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("NodeRegistry Implementation Name: %s", INodeRegistry(implementation_).contractName());
            console.log("NodeRegistry Implementation Version: %s", INodeRegistry(implementation_).version());
            console.log("NodeRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.nodeRegistryImplementation) {
            revert UnexpectedImplementation(_deploymentData.nodeRegistryImplementation, implementation_);
        }

        if (INodeRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                INodeRegistry(implementation_).parameterRegistry()
            );
        }
    }

    function deployNodeRegistryProxy() public {
        if (_deploymentData.nodeRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.nodeRegistryProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.nodeRegistryProxy;
        bool proxyAlreadyExists = proxy_.code.length > 0;

        // Deploy proxy if it doesn't exist
        if (!proxyAlreadyExists) {
            console.log("NodeRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.nodeRegistryProxySalt));

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = NodeRegistryDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.nodeRegistryImplementation,
                _deploymentData.nodeRegistryProxySalt
            );

            vm.stopBroadcast();

            console.log("NodeRegistry Proxy: %s", proxy_);
        }

        // Verify proxy address matches config
        if (proxy_ != _deploymentData.nodeRegistryProxy) {
            revert UnexpectedProxy(_deploymentData.nodeRegistryProxy, proxy_);
        }

        // Verify implementation matches expected
        address currentImplementation_ = INodeRegistry(proxy_).implementation();
        _verifyProxyImplementation(proxy_, _deploymentData.nodeRegistryImplementation, currentImplementation_);

        // If proxy already exists with correct implementation, log no-op
        if (proxyAlreadyExists) {
            console.log("Proxy already exists with correct implementation - no-op");
        }
    }

    function deployPayerReportManagerImplementation() public {
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        address implementation_ = _deploymentData.payerReportManagerImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.nodeRegistryProxy,
                _deploymentData.payerRegistryProxy
            );

            vm.stopBroadcast();

            console.log(
                "PayerReportManager Implementation Name: %s",
                IPayerReportManager(implementation_).contractName()
            );
            console.log(
                "PayerReportManager Implementation Version: %s",
                IPayerReportManager(implementation_).version()
            );
            console.log("PayerReportManager Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.payerReportManagerImplementation) {
            revert UnexpectedImplementation(_deploymentData.payerReportManagerImplementation, implementation_);
        }

        if (IPayerReportManager(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IPayerReportManager(implementation_).parameterRegistry()
            );
        }

        if (IPayerReportManager(implementation_).nodeRegistry() != _deploymentData.nodeRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.nodeRegistryProxy,
                IPayerReportManager(implementation_).nodeRegistry()
            );
        }

        if (IPayerReportManager(implementation_).payerRegistry() != _deploymentData.payerRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.payerRegistryProxy,
                IPayerReportManager(implementation_).payerRegistry()
            );
        }
    }

    function deployPayerReportManagerProxy() public {
        if (_deploymentData.payerReportManagerProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.payerReportManagerProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.payerReportManagerProxy;
        bool proxyAlreadyExists = proxy_.code.length > 0;

        // Deploy proxy if it doesn't exist
        if (!proxyAlreadyExists) {
            console.log(
                "PayerReportManager Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.payerReportManagerProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = PayerReportManagerDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.payerReportManagerImplementation,
                _deploymentData.payerReportManagerProxySalt
            );

            vm.stopBroadcast();

            console.log("PayerReportManager Proxy: %s", proxy_);
        }

        // Verify proxy address matches config
        if (proxy_ != _deploymentData.payerReportManagerProxy) {
            revert UnexpectedProxy(_deploymentData.payerReportManagerProxy, proxy_);
        }

        // Verify implementation matches expected
        address currentImplementation_ = IPayerReportManager(proxy_).implementation();
        _verifyProxyImplementation(proxy_, _deploymentData.payerReportManagerImplementation, currentImplementation_);

        // If proxy already exists with correct implementation, log no-op
        if (proxyAlreadyExists) {
            console.log("Proxy already exists with correct implementation - no-op");
        }
    }

    function deployDistributionManagerImplementation() public {
        if (_deploymentData.distributionManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerReportManagerProxy == address(0)) revert PayerReportManagerProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();

        address implementation_ = _deploymentData.distributionManagerImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = DistributionManagerDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.nodeRegistryProxy,
                _deploymentData.payerReportManagerProxy,
                _deploymentData.payerRegistryProxy,
                _deploymentData.feeTokenProxy
            );

            vm.stopBroadcast();

            console.log(
                "DistributionManager Implementation Name: %s",
                IDistributionManager(implementation_).contractName()
            );
            console.log(
                "DistributionManager Implementation Version: %s",
                IDistributionManager(implementation_).version()
            );
            console.log("DistributionManager Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.distributionManagerImplementation) {
            revert UnexpectedImplementation(_deploymentData.distributionManagerImplementation, implementation_);
        }

        if (IDistributionManager(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IDistributionManager(implementation_).parameterRegistry()
            );
        }

        if (IDistributionManager(implementation_).nodeRegistry() != _deploymentData.nodeRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.nodeRegistryProxy,
                IDistributionManager(implementation_).nodeRegistry()
            );
        }

        if (IDistributionManager(implementation_).payerReportManager() != _deploymentData.payerReportManagerProxy) {
            revert UnexpectedImplementation(
                _deploymentData.payerReportManagerProxy,
                IDistributionManager(implementation_).payerReportManager()
            );
        }

        if (IDistributionManager(implementation_).payerRegistry() != _deploymentData.payerRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.payerRegistryProxy,
                IDistributionManager(implementation_).payerRegistry()
            );
        }

        if (IDistributionManager(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation(
                _deploymentData.feeTokenProxy,
                IDistributionManager(implementation_).feeToken()
            );
        }
    }

    function deployDistributionManagerProxy() public {
        if (_deploymentData.distributionManagerProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.distributionManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.distributionManagerProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.distributionManagerProxy;

        if (proxy_.code.length == 0) {
            console.log(
                "DistributionManager Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.distributionManagerProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = DistributionManagerDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.distributionManagerImplementation,
                _deploymentData.distributionManagerProxySalt
            );

            vm.stopBroadcast();

            console.log("DistributionManager Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.distributionManagerProxy) {
            revert UnexpectedProxy(_deploymentData.distributionManagerProxy, proxy_);
        }

        if (IDistributionManager(proxy_).implementation() != _deploymentData.distributionManagerImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.distributionManagerImplementation,
                IDistributionManager(proxy_).implementation()
            );
        }
    }

    function deployDepositSplitter() public {
        if (_deploymentData.depositSplitter == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (_deploymentData.appChainId == 0) revert AppChainIdNotSet();

        address implementation_ = _deploymentData.depositSplitter;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = DepositSplitterDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.feeTokenProxy,
                _deploymentData.payerRegistryProxy,
                _deploymentData.gatewayProxy,
                _deploymentData.appChainId
            );

            vm.stopBroadcast();

            console.log("DepositSplitter: %s", implementation_);
        }

        if (implementation_ != _deploymentData.depositSplitter) {
            revert UnexpectedImplementation(_deploymentData.depositSplitter, implementation_);
        }

        if (IDepositSplitter(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation(
                _deploymentData.feeTokenProxy,
                IDepositSplitter(implementation_).feeToken()
            );
        }

        if (IDepositSplitter(implementation_).payerRegistry() != _deploymentData.payerRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.payerRegistryProxy,
                IDepositSplitter(implementation_).payerRegistry()
            );
        }

        if (IDepositSplitter(implementation_).settlementChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation(
                _deploymentData.gatewayProxy,
                IDepositSplitter(implementation_).settlementChainGateway()
            );
        }

        if (IDepositSplitter(implementation_).appChainId() != _deploymentData.appChainId) {
            revert("Unexpected appChainId");
        }
    }

    function deployAppChainParameterRegistryImplementation() public {
        if (_deploymentData.appChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        address implementation_ = _deploymentData.appChainParameterRegistryImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(_deploymentData.factory);

            vm.stopBroadcast();

            console.log(
                "AppChainParameterRegistry Implementation Name: %s",
                IAppChainParameterRegistry(implementation_).contractName()
            );
            console.log(
                "AppChainParameterRegistry Implementation Version: %s",
                IAppChainParameterRegistry(implementation_).version()
            );
            console.log("AppChainParameterRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.appChainParameterRegistryImplementation) {
            revert UnexpectedImplementation(_deploymentData.appChainParameterRegistryImplementation, implementation_);
        }
    }

    function deployAppChainParameterRegistryProxy() public {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.appChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.parameterRegistryProxySalt == 0) revert ProxySaltNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();

        address[] memory admins_ = new address[](1);
        admins_[0] = _deploymentData.gatewayProxy;

        address proxy_ = _deploymentData.parameterRegistryProxy;

        if (proxy_.code.length == 0) {
            console.log(
                "AppChainParameterRegistry Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.parameterRegistryProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = AppChainParameterRegistryDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.appChainParameterRegistryImplementation,
                _deploymentData.parameterRegistryProxySalt,
                admins_
            );

            vm.stopBroadcast();

            console.log("AppChainParameterRegistry Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedProxy(_deploymentData.parameterRegistryProxy, proxy_);
        }

        if (
            IAppChainParameterRegistry(proxy_).implementation() !=
            _deploymentData.appChainParameterRegistryImplementation
        ) {
            revert UnexpectedImplementation(
                _deploymentData.appChainParameterRegistryImplementation,
                IAppChainParameterRegistry(proxy_).implementation()
            );
        }

        if (!IAppChainParameterRegistry(proxy_).isAdmin(_deploymentData.gatewayProxy)) {
            revert UnexpectedProxy(_deploymentData.gatewayProxy, address(0));
        }
    }

    function deployAppChainGatewayImplementation() public {
        if (_deploymentData.appChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();

        address implementation_ = _deploymentData.appChainGatewayImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.gatewayProxy
            );

            vm.stopBroadcast();

            console.log("AppChainGateway Implementation Name: %s", IAppChainGateway(implementation_).contractName());
            console.log("AppChainGateway Implementation Version: %s", IAppChainGateway(implementation_).version());
            console.log("AppChainGateway Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.appChainGatewayImplementation) {
            revert UnexpectedImplementation(_deploymentData.appChainGatewayImplementation, implementation_);
        }

        if (IAppChainGateway(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IAppChainGateway(implementation_).parameterRegistry()
            );
        }

        if (IAppChainGateway(implementation_).settlementChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation(
                _deploymentData.gatewayProxy,
                IAppChainGateway(implementation_).settlementChainGateway()
            );
        }

        if (
            IAppChainGateway(implementation_).settlementChainGatewayAlias() !=
            AddressAliasHelper.toAlias(_deploymentData.gatewayProxy)
        ) {
            revert UnexpectedImplementation(
                AddressAliasHelper.toAlias(_deploymentData.gatewayProxy),
                IAppChainGateway(implementation_).settlementChainGatewayAlias()
            );
        }
    }

    function deployAppChainGatewayProxy() public {
        if (_deploymentData.gatewayProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.appChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.gatewayProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.gatewayProxy;

        if (proxy_.code.length == 0) {
            console.log("AppChainGateway Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.gatewayProxySalt));

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = AppChainGatewayDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.appChainGatewayImplementation,
                _deploymentData.gatewayProxySalt
            );

            vm.stopBroadcast();

            console.log("AppChainGateway Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.gatewayProxy) {
            revert UnexpectedProxy(_deploymentData.gatewayProxy, proxy_);
        }

        if (IAppChainGateway(proxy_).implementation() != _deploymentData.appChainGatewayImplementation) {
            revert UnexpectedImplementation(
                _deploymentData.appChainGatewayImplementation,
                IAppChainGateway(proxy_).implementation()
            );
        }
    }

    function deployGroupMessageBroadcasterImplementation() public {
        if (_deploymentData.groupMessageBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = _deploymentData.groupMessageBroadcasterImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log(
                "GroupMessageBroadcaster Implementation Name: %s",
                IGroupMessageBroadcaster(implementation_).contractName()
            );
            console.log(
                "GroupMessageBroadcaster Implementation Version: %s",
                IGroupMessageBroadcaster(implementation_).version()
            );
            console.log("GroupMessageBroadcaster Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.groupMessageBroadcasterImplementation) {
            revert UnexpectedImplementation(_deploymentData.groupMessageBroadcasterImplementation, implementation_);
        }

        if (IGroupMessageBroadcaster(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IGroupMessageBroadcaster(implementation_).parameterRegistry()
            );
        }
    }

    function deployGroupMessageBroadcasterProxy() public {
        if (_deploymentData.groupMessageBroadcasterProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.groupMessageBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.groupMessageBroadcasterProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.groupMessageBroadcasterProxy;

        if (proxy_.code.length == 0) {
            console.log(
                "GroupMessageBroadcaster Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.groupMessageBroadcasterProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.groupMessageBroadcasterImplementation,
                _deploymentData.groupMessageBroadcasterProxySalt
            );

            vm.stopBroadcast();

            console.log("GroupMessageBroadcaster Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.groupMessageBroadcasterProxy) {
            revert UnexpectedProxy(_deploymentData.groupMessageBroadcasterProxy, proxy_);
        }

        if (
            IGroupMessageBroadcaster(proxy_).implementation() != _deploymentData.groupMessageBroadcasterImplementation
        ) {
            revert UnexpectedImplementation(
                _deploymentData.groupMessageBroadcasterImplementation,
                IGroupMessageBroadcaster(proxy_).implementation()
            );
        }
    }

    function deployIdentityUpdateBroadcasterImplementation() public {
        if (_deploymentData.identityUpdateBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = _deploymentData.identityUpdateBroadcasterImplementation;

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log(
                "IdentityUpdateBroadcaster Implementation Name: %s",
                IIdentityUpdateBroadcaster(implementation_).contractName()
            );
            console.log(
                "IdentityUpdateBroadcaster Implementation Version: %s",
                IIdentityUpdateBroadcaster(implementation_).version()
            );
            console.log("IdentityUpdateBroadcaster Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.identityUpdateBroadcasterImplementation) {
            revert UnexpectedImplementation(_deploymentData.identityUpdateBroadcasterImplementation, implementation_);
        }

        if (IIdentityUpdateBroadcaster(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation(
                _deploymentData.parameterRegistryProxy,
                IIdentityUpdateBroadcaster(implementation_).parameterRegistry()
            );
        }
    }

    function deployIdentityUpdateBroadcasterProxy() public {
        if (_deploymentData.identityUpdateBroadcasterProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.identityUpdateBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.identityUpdateBroadcasterProxySalt == 0) revert ProxySaltNotSet();

        address proxy_ = _deploymentData.identityUpdateBroadcasterProxy;

        if (proxy_.code.length == 0) {
            console.log(
                "IdentityUpdateBroadcaster Proxy Salt: %s",
                Utils.bytes32ToString(_deploymentData.identityUpdateBroadcasterProxySalt)
            );

            vm.startBroadcast(_privateKey);

            (proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
                _deploymentData.factory,
                _deploymentData.identityUpdateBroadcasterImplementation,
                _deploymentData.identityUpdateBroadcasterProxySalt
            );

            vm.stopBroadcast();

            console.log("IdentityUpdateBroadcaster Proxy: %s", proxy_);
        }

        if (proxy_ != _deploymentData.identityUpdateBroadcasterProxy) {
            revert UnexpectedProxy(_deploymentData.identityUpdateBroadcasterProxy, proxy_);
        }

        if (
            IIdentityUpdateBroadcaster(proxy_).implementation() !=
            _deploymentData.identityUpdateBroadcasterImplementation
        ) {
            revert UnexpectedImplementation(
                _deploymentData.identityUpdateBroadcasterImplementation,
                IIdentityUpdateBroadcaster(proxy_).implementation()
            );
        }
    }

    /* ============ Internal Functions ============ */

    function _verifyProxyImplementation(
        address proxy_,
        address expectedImplementation_,
        address currentImplementation_
    ) internal {
        if (currentImplementation_ != expectedImplementation_) {
            console.log("ERROR: Proxy points to a different implementation than expected.");
            console.log("  Proxy:", proxy_);
            console.log("  Expected implementation:", expectedImplementation_);
            console.log("  Actual implementation:", currentImplementation_);
            console.log("  You either need to:");
            console.log("    - Change the proxy's salt to get a fresh proxy deploy at new address,");
            console.log("    - Or upgrade the existing proxy (not deploy).");
            revert ProxyExistsWithDifferentImplementation(proxy_, expectedImplementation_, currentImplementation_);
        }
    }

    function _getAdmins() internal view returns (address[] memory admins_) {
        uint256 adminCount_ = _deploymentData.settlementChainParameterRegistryAdmin1 == address(0)
            ? 0
            : _deploymentData.settlementChainParameterRegistryAdmin2 == address(0)
                ? 1
                : _deploymentData.settlementChainParameterRegistryAdmin3 == address(0)
                    ? 2
                    : 3;

        console.log("Admin Count: %s", adminCount_);

        admins_ = new address[](adminCount_);

        for (uint256 index_; index_ < adminCount_; ++index_) {
            if (index_ == 0) {
                admins_[index_] = _deploymentData.settlementChainParameterRegistryAdmin1;
                console.log("Admin 1: %s", admins_[index_]);
            } else if (index_ == 1) {
                admins_[index_] = _deploymentData.settlementChainParameterRegistryAdmin2;
                console.log("Admin 2: %s", admins_[index_]);
            } else {
                admins_[index_] = _deploymentData.settlementChainParameterRegistryAdmin3;
                console.log("Admin 3: %s", admins_[index_]);
            }
        }
    }

    function _writeSettlementChainData(uint256 blockNumber_) internal {
        _prepareEnvironmentJson(_ensureNoSettlementChainData);

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        vm.serializeJson("root", vm.readFile(filePath_));
        vm.serializeUint("root", "settlementChainId", block.chainid);
        vm.serializeUint("root", "settlementChainDeploymentBlock", blockNumber_);
        vm.serializeAddress("root", "settlementChainFactory", _deploymentData.factory);
        vm.serializeAddress("root", "settlementChainParameterRegistry", _deploymentData.parameterRegistryProxy);
        vm.serializeAddress("root", "settlementChainGateway", _deploymentData.gatewayProxy);
        vm.serializeAddress("root", "feeToken", _deploymentData.feeTokenProxy);
        vm.serializeAddress("root", "underlyingFeeToken", _deploymentData.underlyingFeeToken);
        vm.serializeAddress("root", "distributionManager", _deploymentData.distributionManagerProxy);
        vm.serializeAddress("root", "nodeRegistry", _deploymentData.nodeRegistryProxy);
        vm.serializeAddress("root", "payerRegistry", _deploymentData.payerRegistryProxy);
        vm.serializeAddress("root", "payerReportManager", _deploymentData.payerReportManagerProxy);
        vm.serializeAddress("root", "depositSplitter", _deploymentData.depositSplitter);

        string memory json_ = vm.serializeAddress("root", "rateRegistry", _deploymentData.rateRegistryProxy);

        vm.writeJson(json_, filePath_);
    }

    function _writeAppChainData(uint256 blockNumber_) internal {
        _prepareEnvironmentJson(_ensureNoAppChainData);

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        vm.serializeJson("root", vm.readFile(filePath_));
        vm.serializeUint("root", "appChainId", block.chainid);
        vm.serializeUint("root", "appChainDeploymentBlock", blockNumber_);
        vm.serializeAddress("root", "appChainFactory", _deploymentData.factory);
        vm.serializeAddress("root", "appChainParameterRegistry", _deploymentData.parameterRegistryProxy);
        vm.serializeAddress("root", "appChainGateway", _deploymentData.gatewayProxy);
        vm.serializeAddress("root", "groupMessageBroadcaster", _deploymentData.groupMessageBroadcasterProxy);

        string memory json_ = vm.serializeAddress(
            "root",
            "identityUpdateBroadcaster",
            _deploymentData.identityUpdateBroadcasterProxy
        );

        vm.writeJson(json_, filePath_);
    }

    function _prepareEnvironmentJson(function(string memory) internal existingDataChecker_) internal {
        if (!vm.isDir("environments")) {
            vm.createDir("environments", true);
        }

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        if (vm.isFile(filePath_)) {
            string memory json_ = vm.readFile(filePath_);

            // Check that the deployer is as expected.
            if (vm.parseJsonAddress(json_, ".deployer") != _deployer) revert EnvironmentContainsUnexpectedDeployer();

            // Check that settlement chain data is not already present.
            existingDataChecker_(json_);
        } else {
            // Write a starting json file with the  deployer.
            vm.writeJson(vm.serializeAddress("", "deployer", _deployer), filePath_);
        }
    }

    function _ensureNoSettlementChainData(string memory json_) internal view {
        if (
            vm.keyExists(json_, ".settlementChainId") ||
            vm.keyExists(json_, ".settlementChainDeploymentBlock") ||
            vm.keyExists(json_, ".settlementChainFactory") ||
            vm.keyExists(json_, ".settlementChainParameterRegistry") ||
            vm.keyExists(json_, ".settlementChainGateway") ||
            vm.keyExists(json_, ".feeToken") ||
            vm.keyExists(json_, ".underlyingFeeToken") ||
            vm.keyExists(json_, ".distributionManager") ||
            vm.keyExists(json_, ".nodeRegistry") ||
            vm.keyExists(json_, ".payerRegistry") ||
            vm.keyExists(json_, ".payerReportManager") ||
            vm.keyExists(json_, ".rateRegistry")
        ) {
            revert EnvironmentContainsSettlementChainData();
        }
    }

    function _ensureNoAppChainData(string memory json_) internal view {
        if (
            vm.keyExists(json_, ".appChainId") ||
            vm.keyExists(json_, ".appChainDeploymentBlock") ||
            vm.keyExists(json_, ".appChainFactory") ||
            vm.keyExists(json_, ".appChainParameterRegistry") ||
            vm.keyExists(json_, ".appChainGateway") ||
            vm.keyExists(json_, ".groupMessageBroadcaster") ||
            vm.keyExists(json_, ".identityUpdateBroadcaster")
        ) {
            revert EnvironmentContainsAppChainData();
        }
    }
}
