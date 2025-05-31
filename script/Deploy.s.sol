// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { FactoryDeployer } from "./deployers/FactoryDeployer.sol";
import { PayerRegistryDeployer } from "./deployers/PayerRegistryDeployer.sol";
import { SettlementChainGatewayDeployer } from "./deployers/SettlementChainGatewayDeployer.sol";
import { SettlementChainParameterRegistryDeployer } from "./deployers/SettlementChainParameterRegistryDeployer.sol";
import { RateRegistryDeployer } from "./deployers/RateRegistryDeployer.sol";
import { NodeRegistryDeployer } from "./deployers/NodeRegistryDeployer.sol";
import { PayerReportManagerDeployer } from "./deployers/PayerReportManagerDeployer.sol";
import { DistributionManagerDeployer } from "./deployers/DistributionManagerDeployer.sol";
import { AppChainParameterRegistryDeployer } from "./deployers/AppChainParameterRegistryDeployer.sol";
import { AppChainGatewayDeployer } from "./deployers/AppChainGatewayDeployer.sol";
import { GroupMessageBroadcasterDeployer } from "./deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "./deployers/IdentityUpdateBroadcasterDeployer.sol";

import { AddressAliasHelper } from "../src/libraries/AddressAliasHelper.sol";

import { IPayerRegistry } from "../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { ISettlementChainGateway } from "../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IRateRegistry } from "../src/settlement-chain/interfaces/IRateRegistry.sol";
import { INodeRegistry } from "../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerReportManager } from "../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IDistributionManager } from "../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IAppChainParameterRegistry } from "../src/app-chain/interfaces/IAppChainParameterRegistry.sol";
import { IAppChainGateway } from "../src/app-chain/interfaces/IAppChainGateway.sol";
import { IGroupMessageBroadcaster } from "../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";

import {
    ISettlementChainParameterRegistry
} from "../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

import { Utils } from "./utils/Utils.sol";

contract DeployScripts is Script {
    error AppChainNativeTokenNotSet();
    error DeployerNotSet();
    error EnvironmentContainsAppChainData();
    error EnvironmentContainsSettlementChainData();
    error EnvironmentContainsUnexpectedDeployer();
    error EnvironmentNotSet();
    error FactoryNotSet();
    error GatewayProxyNotSet();
    error ImplementationNotSet();
    error NodeRegistryProxyNotSet();
    error ParameterRegistryProxyNotSet();
    error PayerRegistryProxyNotSet();
    error PayerReportManagerProxyNotSet();
    error PrivateKeyNotSet();
    error ProxyNotSet();
    error ProxySaltNotSet();
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

    function deploySettlementChainComponents() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        uint256 blockNumber_ = block.number;

        deployFactory();
        deploySettlementChainParameterRegistryImplementation();
        deploySettlementChainParameterRegistryProxy();
        deploySettlementChainGatewayImplementation();
        deploySettlementChainGatewayProxy();
        deployPayerRegistryImplementation();
        deployPayerRegistryProxy();
        deployRateRegistryImplementation();
        deployRateRegistryProxy();
        deployNodeRegistryImplementation();
        deployNodeRegistryProxy();
        deployPayerReportManagerImplementation();
        deployPayerReportManagerProxy();
        deployDistributionManagerImplementation();
        deployDistributionManagerProxy();

        _writeSettlementChainData(blockNumber_);
    }

    function deployAppChainComponents() external {
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        uint256 blockNumber_ = block.number;

        deployFactory();
        deployAppChainParameterRegistryImplementation();
        deployAppChainParameterRegistryProxy();
        deployAppChainGatewayImplementation();
        deployAppChainGatewayProxy();
        deployGroupMessageBroadcasterImplementation();
        deployGroupMessageBroadcasterProxy();
        deployIdentityUpdateBroadcasterImplementation();
        deployIdentityUpdateBroadcasterProxy();

        _writeAppChainData(blockNumber_);
    }

    function verifySettlementChainComponents() external {
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        string memory json_ = vm.readFile(filePath_);

        // TODO: For some or all of these, check a getter to ensure the contracts are as expected.

        if (vm.parseJsonUint(json_, ".settlementChainId") != block.chainid) revert("Settlement chain ID mismatch");

        if (vm.parseJsonAddress(json_, ".settlementChainFactory").code.length == 0) {
            revert("Settlement chain factory does not exist");
        }

        if (vm.parseJsonAddress(json_, ".appChainNativeToken").code.length == 0) {
            revert("Appchain native token does not exist");
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
    }

    function verifyAppChainComponents() external {
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

    function deployFactory() public returns (address factory_) {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        vm.startBroadcast(_privateKey);

        factory_ = FactoryDeployer.deploy();

        console.log("Factory: %s", factory_);

        if (factory_ != _deploymentData.factory) revert UnexpectedFactory();

        vm.stopBroadcast();
    }

    function deploySettlementChainParameterRegistryImplementation() public returns (address implementation_) {
        if (_deploymentData.settlementChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(_deploymentData.factory);

        vm.stopBroadcast();

        console.log("SettlementChainParameterRegistry Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.settlementChainParameterRegistryImplementation)
            revert UnexpectedImplementation();
    }

    function deploySettlementChainParameterRegistryProxy() public returns (address proxy_) {
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

        (proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
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

    function deploySettlementChainGatewayImplementation() public returns (address implementation_) {
        if (_deploymentData.settlementChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (_deploymentData.appChainNativeToken == address(0)) revert AppChainNativeTokenNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy,
            _deploymentData.appChainNativeToken
        );

        vm.stopBroadcast();

        console.log("SettlementChainGateway Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.settlementChainGatewayImplementation) revert UnexpectedImplementation();

        if (ISettlementChainGateway(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (ISettlementChainGateway(implementation_).appChainGateway() != _deploymentData.gatewayProxy) {
            revert UnexpectedImplementation();
        }

        if (ISettlementChainGateway(implementation_).appChainNativeToken() != _deploymentData.appChainNativeToken) {
            revert UnexpectedImplementation();
        }
    }

    function deploySettlementChainGatewayProxy() public returns (address proxy_) {
        if (_deploymentData.gatewayProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.settlementChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.gatewayProxySalt == 0) revert ProxySaltNotSet();

        console.log("SettlementChainGateway Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.gatewayProxySalt));

        vm.startBroadcast(_privateKey);

        (proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
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

    function deployPayerRegistryImplementation() public returns (address implementation_) {
        if (_deploymentData.payerRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.appChainNativeToken == address(0)) revert AppChainNativeTokenNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = PayerRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.appChainNativeToken
        );

        vm.stopBroadcast();

        console.log("PayerRegistry Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.payerRegistryImplementation) revert UnexpectedImplementation();

        if (IPayerRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }

        if (IPayerRegistry(implementation_).token() != _deploymentData.appChainNativeToken) {
            revert UnexpectedImplementation();
        }
    }

    function deployPayerRegistryProxy() public returns (address proxy_) {
        if (_deploymentData.payerRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.payerRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.payerRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log("PayerRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.payerRegistryProxySalt));

        vm.startBroadcast(_privateKey);

        (proxy_, , ) = PayerRegistryDeployer.deployProxy(
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

    function deployRateRegistryImplementation() public returns (address implementation_) {
        if (_deploymentData.rateRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = RateRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        vm.stopBroadcast();

        console.log("RateRegistry Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.rateRegistryImplementation) revert UnexpectedImplementation();

        if (IRateRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployRateRegistryProxy() public returns (address proxy_) {
        if (_deploymentData.rateRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.rateRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.rateRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log("RateRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.rateRegistryProxySalt));

        vm.startBroadcast(_privateKey);

        (proxy_, , ) = RateRegistryDeployer.deployProxy(
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

    function deployNodeRegistryImplementation() public returns (address implementation_) {
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = NodeRegistryDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        vm.stopBroadcast();

        console.log("NodeRegistry Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.nodeRegistryImplementation) revert UnexpectedImplementation();

        if (INodeRegistry(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployNodeRegistryProxy() public returns (address proxy_) {
        if (_deploymentData.nodeRegistryProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.nodeRegistryProxySalt == 0) revert ProxySaltNotSet();

        console.log("NodeRegistry Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.nodeRegistryProxySalt));

        vm.startBroadcast(_privateKey);

        (proxy_, , ) = NodeRegistryDeployer.deployProxy(
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

    function deployPayerReportManagerImplementation() public returns (address implementation_) {
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerRegistryProxy
        );

        vm.stopBroadcast();

        console.log("PayerReportManager Implementation: %s", implementation_);

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

    function deployPayerReportManagerProxy() public returns (address proxy_) {
        if (_deploymentData.payerReportManagerProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.payerReportManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.payerReportManagerProxySalt == 0) revert ProxySaltNotSet();

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

        if (proxy_ != _deploymentData.payerReportManagerProxy) revert UnexpectedProxy();

        if (IPayerReportManager(proxy_).implementation() != _deploymentData.payerReportManagerImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployDistributionManagerImplementation() public returns (address implementation_) {
        if (_deploymentData.distributionManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (_deploymentData.payerReportManagerProxy == address(0)) revert PayerReportManagerProxyNotSet();
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (_deploymentData.appChainNativeToken == address(0)) revert AppChainNativeTokenNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.nodeRegistryProxy,
            _deploymentData.payerReportManagerProxy,
            _deploymentData.payerRegistryProxy,
            _deploymentData.appChainNativeToken
        );

        vm.stopBroadcast();

        console.log("DistributionManager Implementation: %s", implementation_);

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

        if (IDistributionManager(implementation_).token() != _deploymentData.appChainNativeToken) {
            revert UnexpectedImplementation();
        }
    }

    function deployDistributionManagerProxy() public returns (address proxy_) {
        if (_deploymentData.distributionManagerProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.distributionManagerImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.distributionManagerProxySalt == 0) revert ProxySaltNotSet();

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

        if (proxy_ != _deploymentData.distributionManagerProxy) revert UnexpectedProxy();

        if (IDistributionManager(proxy_).implementation() != _deploymentData.distributionManagerImplementation) {
            revert UnexpectedProxy();
        }
    }

    function deployAppChainParameterRegistryImplementation() public returns (address implementation_) {
        if (_deploymentData.appChainParameterRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(_deploymentData.factory);

        vm.stopBroadcast();

        console.log("AppChainParameterRegistry Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.appChainParameterRegistryImplementation) {
            revert UnexpectedImplementation();
        }
    }

    function deployAppChainParameterRegistryProxy() public returns (address proxy_) {
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

        (proxy_, , ) = AppChainParameterRegistryDeployer.deployProxy(
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

    function deployAppChainGatewayImplementation() public returns (address implementation_) {
        if (_deploymentData.appChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy,
            _deploymentData.gatewayProxy
        );

        vm.stopBroadcast();

        console.log("AppChainGateway Implementation: %s", implementation_);

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

    function deployAppChainGatewayProxy() public returns (address proxy_) {
        if (_deploymentData.gatewayProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.appChainGatewayImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.gatewayProxySalt == 0) revert ProxySaltNotSet();

        console.log("AppChainGateway Proxy Salt: %s", Utils.bytes32ToString(_deploymentData.gatewayProxySalt));

        vm.startBroadcast(_privateKey);

        (proxy_, , ) = AppChainGatewayDeployer.deployProxy(
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

    function deployGroupMessageBroadcasterImplementation() public returns (address implementation_) {
        if (_deploymentData.groupMessageBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        vm.stopBroadcast();

        console.log("GroupMessageBroadcaster Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.groupMessageBroadcasterImplementation) revert UnexpectedImplementation();

        if (IGroupMessageBroadcaster(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployGroupMessageBroadcasterProxy() public returns (address proxy_) {
        if (_deploymentData.groupMessageBroadcasterProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.groupMessageBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.groupMessageBroadcasterProxySalt == 0) revert ProxySaltNotSet();

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

        if (proxy_ != _deploymentData.groupMessageBroadcasterProxy) revert UnexpectedProxy();

        if (
            IGroupMessageBroadcaster(proxy_).implementation() != _deploymentData.groupMessageBroadcasterImplementation
        ) {
            revert UnexpectedProxy();
        }
    }

    function deployIdentityUpdateBroadcasterImplementation() public returns (address implementation_) {
        if (_deploymentData.identityUpdateBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        vm.startBroadcast(_privateKey);

        (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        vm.stopBroadcast();

        console.log("IdentityUpdateBroadcaster Implementation: %s", implementation_);

        if (implementation_ != _deploymentData.identityUpdateBroadcasterImplementation) {
            revert UnexpectedImplementation();
        }

        if (IIdentityUpdateBroadcaster(implementation_).parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            revert UnexpectedImplementation();
        }
    }

    function deployIdentityUpdateBroadcasterProxy() public returns (address proxy_) {
        if (_deploymentData.identityUpdateBroadcasterProxy == address(0)) revert ProxyNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.identityUpdateBroadcasterImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.identityUpdateBroadcasterProxySalt == 0) revert ProxySaltNotSet();

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
        vm.serializeAddress("root", "appChainNativeToken", _deploymentData.appChainNativeToken);
        vm.serializeAddress("root", "distributionManager", _deploymentData.distributionManagerProxy);
        vm.serializeAddress("root", "nodeRegistry", _deploymentData.nodeRegistryProxy);
        vm.serializeAddress("root", "payerRegistry", _deploymentData.payerRegistryProxy);
        vm.serializeAddress("root", "payerReportManager", _deploymentData.payerReportManagerProxy);

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

    function _ensureNoSettlementChainData(string memory json_) internal {
        if (
            vm.keyExists(json_, ".settlementChainId") ||
            vm.keyExists(json_, ".settlementChainDeploymentBlock") ||
            vm.keyExists(json_, ".settlementChainFactory") ||
            vm.keyExists(json_, ".settlementChainParameterRegistry") ||
            vm.keyExists(json_, ".settlementChainGateway") ||
            vm.keyExists(json_, ".appChainNativeToken") ||
            vm.keyExists(json_, ".distributionManager") ||
            vm.keyExists(json_, ".nodeRegistry") ||
            vm.keyExists(json_, ".payerRegistry") ||
            vm.keyExists(json_, ".payerReportManager") ||
            vm.keyExists(json_, ".rateRegistry")
        ) {
            revert EnvironmentContainsSettlementChainData();
        }
    }

    function _ensureNoAppChainData(string memory json_) internal {
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
