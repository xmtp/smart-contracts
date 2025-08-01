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
    error UnexpectedImplementation();
    error UnexpectedProxy();

    Utils.DeploymentData internal _deploymentData;

    string internal _environment;

    uint256 internal _privateKey;
    address internal _deployer;

    function setUp() external {
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

        vm.startBroadcast(_privateKey);

        (address implementation_, ) = FactoryDeployer.deployImplementation(_deploymentData.parameterRegistryProxy);

        vm.stopBroadcast();

        console.log("Factory Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.factoryImplementation) revert UnexpectedImplementation();

        if (IFactory(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployFactoryImplementationViaFactory() public {
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = FactoryDeployer.getImplementationViaFactory(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = FactoryDeployer.deployImplementationViaFactory(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("Factory Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.factoryImplementation) revert UnexpectedImplementation();

        if (IFactory(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployFactoryProxy() public {
        if (_deploymentData.factory == address(0)) revert ProxyNotSet();
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = FactoryDeployer.deployProxy(_deploymentData.factoryImplementation);

        vm.stopBroadcast();

        console.log("Factory Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.factory) revert UnexpectedProxy();

        // NOTE: The factory implementation may not yet be deployed, so `factory_.implementation()` may revert.
    }

    function initializeFactory() public {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.factoryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.initializableImplementation == address(0)) revert InitializableImplementationNotSet();

        vm.startBroadcast(_privateKey);
        IFactory(_deploymentData.factory).initialize();
        vm.stopBroadcast();

        if (IFactory(_deploymentData.factory).implementation() != _deploymentData.factoryImplementation) {
            revert UnexpectedProxy();
        }

        if (
            IFactory(_deploymentData.factory).initializableImplementation() !=
            _deploymentData.initializableImplementation
        ) {
            revert UnexpectedProxy();
        }
    }

    function deploySettlementChainParameterRegistryImplementation() public {
        if (_deploymentData.settlementChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        address implementation_ = SettlementChainParameterRegistryDeployer.getImplementation(_deploymentData.factory);

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(
                _deploymentData.factory
            );

            vm.stopBroadcast();

            console.log("SettlementChainParameterRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.settlementChainParameterRegistryImplementation) {
            revert UnexpectedImplementation();
        }
    }

    function deploySettlementChainParameterRegistryProxy() public {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.settlementChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.parameterRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log(
            "SettlementChainParameterRegistry Proxy Salt: %s",
            Utils.bytes32ToString(_deploymentData.parameterRegistryProxySalt)
        );

        address[] memory admins_ = _getAdmins();

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.settlementChainParameterRegistryImplementation,
            _deploymentData.parameterRegistryProxySalt,
            admins_
        );

        vm.stopBroadcast();

        console.log("SettlementChainParameterRegistry Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.parameterRegistryProxy) revert UnexpectedProxy();

        if (
            ISettlementChainParameterRegistry(proxy_).implementation() !=
            _deploymentData.settlementChainParameterRegistryImplementation
        ) {
            revert UnexpectedProxy();
        }

        for (uint256 index_; index_ < admins_.length; ++index_) {
            if (!ISettlementChainParameterRegistry(proxy_).isAdmin(admins_[index_])) revert UnexpectedProxy();
        }
    }

    function deployMockUnderlyingFeeTokenImplementation() public {
        // Skip deployment if the mock underlying fee token implementation is not set.
        if (_deploymentData.mockUnderlyingFeeTokenImplementation == address(0)) return;

        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = MockUnderlyingFeeTokenDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = MockUnderlyingFeeTokenDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("MockUnderlyingFeeToken Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.mockUnderlyingFeeTokenImplementation) revert UnexpectedImplementation();

        if (MockUnderlyingFeeToken(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployMockUnderlyingFeeTokenProxy() public {
        // Skip deployment if the mock underlying fee token implementation is not set.
        if (_deploymentData.mockUnderlyingFeeTokenImplementation == address(0)) return;

        if (_deploymentData.underlyingFeeToken == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.mockUnderlyingFeeTokenProxySalt == 0) revert ProxySaltNotSet();

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = MockUnderlyingFeeTokenDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.mockUnderlyingFeeTokenImplementation,
            _deploymentData.mockUnderlyingFeeTokenProxySalt
        );

        vm.stopBroadcast();

        console.log("MockUnderlyingFeeToken Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.underlyingFeeToken) revert UnexpectedProxy();

        if (MockUnderlyingFeeToken(proxy_).implementation() != _deploymentData.mockUnderlyingFeeTokenImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployFeeTokenImplementation() public {
        if (_deploymentData.feeTokenImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.underlyingFeeToken == address(0)) revert UnderlyingFeeTokenNotSet();

        address implementation_ = FeeTokenDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.underlyingFeeToken
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = FeeTokenDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.underlyingFeeToken
            );

            vm.stopBroadcast();

            console.log("FeeToken Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.feeTokenImplementation) revert UnexpectedImplementation();

        if (IFeeToken(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IFeeToken(implementation_).underlying() != _deploymentData.underlyingFeeToken) {
            revert UnexpectedImplementation();
        }
    }

    function deployFeeTokenProxy() public {
        if (_deploymentData.feeTokenProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.feeTokenImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.feeTokenProxySalt == 0) revert ProxySaltNotSet();

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = FeeTokenDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.feeTokenImplementation,
            _deploymentData.feeTokenProxySalt
        );

        vm.stopBroadcast();

        console.log("FeeToken Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.feeTokenProxy) revert UnexpectedProxy();

        if (IFeeToken(proxy_).implementation() != _deploymentData.feeTokenImplementation) revert UnexpectedProxy();
    }

    function deploySettlementChainGatewayImplementation() public {
        if (_deploymentData.settlementChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();

        address implementation_ = SettlementChainGatewayDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy,
            _deploymentData.feeTokenProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.gatewayProxy,
                _deploymentData.feeTokenProxy
            );

            vm.stopBroadcast();

            console.log("SettlementChainGateway Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.settlementChainGatewayImplementation) revert UnexpectedImplementation();

        if (ISettlementChainGateway(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (ISettlementChainGateway(implementation_).appChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation();
        }

        if (ISettlementChainGateway(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deploySettlementChainGatewayProxy() public {
        if (_deploymentData.gatewayProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.settlementChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.gatewayProxySalt == 0) revert ProxySaltNotSet();

        console.log("SettlementChainGateway Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.gatewayProxySalt));

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.settlementChainGatewayImplementation,
            _deploymentData.gatewayProxySalt
        );

        vm.stopBroadcast();

        console.log("SettlementChainGateway Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.gatewayProxy) revert UnexpectedProxy();

        if (ISettlementChainGateway(proxy_).implementation() != _deploymentData.settlementChainGatewayImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployPayerRegistryImplementation() public {
        if (_deploymentData.payerRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();

        address implementation_ = PayerRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.feeTokenProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = PayerRegistryDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.feeTokenProxy
            );

            vm.stopBroadcast();

            console.log("PayerRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.payerRegistryImplementation) revert UnexpectedImplementation();

        if (IPayerRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IPayerRegistry(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployPayerRegistryProxy() public {
        if (_deploymentData.payerRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.payerRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.payerRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log("PayerRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.payerRegistryProxySalt));

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = PayerRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.payerRegistryImplementation,
            _deploymentData.payerRegistryProxySalt
        );

        vm.stopBroadcast();

        console.log("PayerRegistry Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.payerRegistryProxy) revert UnexpectedProxy();

        if (IPayerRegistry(proxy_).implementation() != _deploymentData.payerRegistryImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployRateRegistryImplementation() public {
        if (_deploymentData.rateRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = RateRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = RateRegistryDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("RateRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.rateRegistryImplementation) revert UnexpectedImplementation();

        if (IRateRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployRateRegistryProxy() public {
        if (_deploymentData.rateRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.rateRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.rateRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log("RateRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.rateRegistryProxySalt));

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = RateRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.rateRegistryImplementation,
            _deploymentData.rateRegistryProxySalt
        );

        vm.stopBroadcast();

        console.log("RateRegistry Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.rateRegistryProxy) revert UnexpectedProxy();

        if (IRateRegistry(proxy_).implementation() != _deploymentData.rateRegistryImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployNodeRegistryImplementation() public {
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = NodeRegistryDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("NodeRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.nodeRegistryImplementation) revert UnexpectedImplementation();

        if (INodeRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployNodeRegistryProxy() public {
        if (_deploymentData.nodeRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.nodeRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log("NodeRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.nodeRegistryProxySalt));

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = NodeRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.nodeRegistryImplementation,
            _deploymentData.nodeRegistryProxySalt
        );

        vm.stopBroadcast();

        console.log("NodeRegistry Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.nodeRegistryProxy) revert UnexpectedProxy();

        if (INodeRegistry(proxy_).implementation() != _deploymentData.nodeRegistryImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployPayerReportManagerImplementation() public {
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        address implementation_ = PayerReportManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.nodeRegistryProxy,
                _deploymentData.payerRegistryProxy
            );

            vm.stopBroadcast();

            console.log("PayerReportManager Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.payerReportManagerImplementation) revert UnexpectedImplementation();

        if (IPayerReportManager(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IPayerReportManager(implementation_).nodeRegistry() != _deploymentData.nodeRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IPayerReportManager(implementation_).payerRegistry() != _deploymentData.payerRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployPayerReportManagerProxy() public {
        if (_deploymentData.payerReportManagerProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.payerReportManagerProxySalt == 0) revert ProxySaltNotSet();

        console.log(
            "PayerReportManager Proxy Salt: %s",
            Utils.bytes32ToString(_deploymentData.payerReportManagerProxySalt)
        );

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = PayerReportManagerDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.payerReportManagerImplementation,
            _deploymentData.payerReportManagerProxySalt
        );

        vm.stopBroadcast();

        console.log("PayerReportManager Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.payerReportManagerProxy) revert UnexpectedProxy();

        if (IPayerReportManager(proxy_).implementation() != _deploymentData.payerReportManagerImplementation) {
            revert UnexpectedProxy();
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

        address implementation_ = DistributionManagerDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerReportManagerProxy,
            _deploymentData.payerRegistryProxy,
            _deploymentData.feeTokenProxy
        );

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

            console.log("DistributionManager Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.distributionManagerImplementation) revert UnexpectedImplementation();

        if (IDistributionManager(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IDistributionManager(implementation_).nodeRegistry() != _deploymentData.nodeRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IDistributionManager(implementation_).payerReportManager() != _deploymentData.payerReportManagerProxy) {
            revert UnexpectedImplementation();
        }

        if (IDistributionManager(implementation_).payerRegistry() != _deploymentData.payerRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IDistributionManager(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployDistributionManagerProxy() public {
        if (_deploymentData.distributionManagerProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.distributionManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.distributionManagerProxySalt == 0) revert ProxySaltNotSet();

        console.log(
            "DistributionManager Proxy Salt: %s",
            Utils.bytes32ToString(_deploymentData.distributionManagerProxySalt)
        );

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = DistributionManagerDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.distributionManagerImplementation,
            _deploymentData.distributionManagerProxySalt
        );

        vm.stopBroadcast();

        console.log("DistributionManager Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.distributionManagerProxy) revert UnexpectedProxy();

        if (IDistributionManager(proxy_).implementation() != _deploymentData.distributionManagerImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployDepositSplitter() public {
        if (_deploymentData.depositSplitter == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.feeTokenProxy == address(0)) revert FeeTokenProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (_deploymentData.appChainId == 0) revert AppChainIdNotSet();

        address implementation_ = DepositSplitterDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.feeTokenProxy,
            _deploymentData.payerRegistryProxy,
            _deploymentData.gatewayProxy,
            _deploymentData.appChainId
        );

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

        if (implementation_ != _deploymentData.depositSplitter) revert UnexpectedImplementation();

        if (IDepositSplitter(implementation_).feeToken() != _deploymentData.feeTokenProxy) {
            revert UnexpectedImplementation();
        }

        if (IDepositSplitter(implementation_).payerRegistry() != _deploymentData.payerRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IDepositSplitter(implementation_).settlementChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation();
        }

        if (IDepositSplitter(implementation_).appChainId() != _deploymentData.appChainId) {
            revert UnexpectedImplementation();
        }
    }

    function deployAppChainParameterRegistryImplementation() public {
        if (_deploymentData.appChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        address implementation_ = AppChainParameterRegistryDeployer.getImplementation(_deploymentData.factory);

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(_deploymentData.factory);

            vm.stopBroadcast();

            console.log("AppChainParameterRegistry Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.appChainParameterRegistryImplementation) {
            revert UnexpectedImplementation();
        }
    }

    function deployAppChainParameterRegistryProxy() public {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.appChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.parameterRegistryProxySalt == 0) revert ProxySaltNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();

        console.log(
            "AppChainParameterRegistry Proxy Salt: %s",
            Utils.bytes32ToString(_deploymentData.parameterRegistryProxySalt)
        );

        address[] memory admins_ = new address[](1);
        admins_[0] = _deploymentData.gatewayProxy;

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = AppChainParameterRegistryDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.appChainParameterRegistryImplementation,
            _deploymentData.parameterRegistryProxySalt,
            admins_
        );

        vm.stopBroadcast();

        console.log("AppChainParameterRegistry Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.parameterRegistryProxy) revert UnexpectedProxy();

        if (
            IAppChainParameterRegistry(proxy_).implementation() !=
            _deploymentData.appChainParameterRegistryImplementation
        ) {
            revert UnexpectedProxy();
        }

        if (!IAppChainParameterRegistry(proxy_).isAdmin(_deploymentData.gatewayProxy)) revert UnexpectedProxy();
    }

    function deployAppChainGatewayImplementation() public {
        if (_deploymentData.appChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();

        address implementation_ = AppChainGatewayDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy,
                _deploymentData.gatewayProxy
            );

            vm.stopBroadcast();

            console.log("AppChainGateway Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.appChainGatewayImplementation) revert UnexpectedImplementation();

        if (IAppChainGateway(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IAppChainGateway(implementation_).settlementChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation();
        }

        if (
            IAppChainGateway(implementation_).settlementChainGatewayAlias() !=
            AddressAliasHelper.toAlias(_deploymentData.gatewayProxy)
        ) {
            revert UnexpectedImplementation();
        }
    }

    function deployAppChainGatewayProxy() public {
        if (_deploymentData.gatewayProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.appChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.gatewayProxySalt == 0) revert ProxySaltNotSet();

        console.log("AppChainGateway Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.gatewayProxySalt));

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = AppChainGatewayDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.appChainGatewayImplementation,
            _deploymentData.gatewayProxySalt
        );

        vm.stopBroadcast();

        console.log("AppChainGateway Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.gatewayProxy) revert UnexpectedProxy();

        if (IAppChainGateway(proxy_).implementation() != _deploymentData.appChainGatewayImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployGroupMessageBroadcasterImplementation() public {
        if (_deploymentData.groupMessageBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = GroupMessageBroadcasterDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("GroupMessageBroadcaster Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.groupMessageBroadcasterImplementation) revert UnexpectedImplementation();

        if (IGroupMessageBroadcaster(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployGroupMessageBroadcasterProxy() public {
        if (_deploymentData.groupMessageBroadcasterProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.groupMessageBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.groupMessageBroadcasterProxySalt == 0) revert ProxySaltNotSet();

        console.log(
            "GroupMessageBroadcaster Proxy Salt: %s",
            Utils.bytes32ToString(_deploymentData.groupMessageBroadcasterProxySalt)
        );

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.groupMessageBroadcasterImplementation,
            _deploymentData.groupMessageBroadcasterProxySalt
        );

        vm.stopBroadcast();

        console.log("GroupMessageBroadcaster Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.groupMessageBroadcasterProxy) revert UnexpectedProxy();

        if (
            IGroupMessageBroadcaster(proxy_).implementation() != _deploymentData.groupMessageBroadcasterImplementation
        ) {
            revert UnexpectedProxy();
        }
    }

    function deployIdentityUpdateBroadcasterImplementation() public {
        if (_deploymentData.identityUpdateBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        address implementation_ = IdentityUpdateBroadcasterDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        if (implementation_.code.length == 0) {
            vm.startBroadcast(_privateKey);

            (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
                _deploymentData.factory,
                _deploymentData.parameterRegistryProxy
            );

            vm.stopBroadcast();

            console.log("IdentityUpdateBroadcaster Implementation: %s", implementation_);
        }

        if (implementation_ != _deploymentData.identityUpdateBroadcasterImplementation) {
            revert UnexpectedImplementation();
        }

        if (IIdentityUpdateBroadcaster(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployIdentityUpdateBroadcasterProxy() public {
        if (_deploymentData.identityUpdateBroadcasterProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.identityUpdateBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.identityUpdateBroadcasterProxySalt == 0) revert ProxySaltNotSet();

        console.log(
            "IdentityUpdateBroadcaster Proxy Salt: %s",
            Utils.bytes32ToString(_deploymentData.identityUpdateBroadcasterProxySalt)
        );

        vm.startBroadcast(_privateKey);

        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            _deploymentData.factory,
            _deploymentData.identityUpdateBroadcasterImplementation,
            _deploymentData.identityUpdateBroadcasterProxySalt
        );

        vm.stopBroadcast();

        console.log("IdentityUpdateBroadcaster Proxy: %s", proxy_);

        if (proxy_ != _deploymentData.identityUpdateBroadcasterProxy) revert UnexpectedProxy();

        if (
            IIdentityUpdateBroadcaster(proxy_).implementation() !=
            _deploymentData.identityUpdateBroadcasterImplementation
        ) revert UnexpectedProxy();
    }

    /* ============ Internal Functions ============ */

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
