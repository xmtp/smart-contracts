pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";

/* ============ Source Interface Imports ============ */

import { IERC1967 } from "../src/abstract/interfaces/IERC1967.sol";
import { IDistributionManager } from "../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
import { IFeeToken } from "../src/settlement-chain/interfaces/IFeeToken.sol";
import { IGroupMessageBroadcaster } from "../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { INodeRegistry } from "../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../src/settlement-chain/interfaces/IRateRegistry.sol";

import {
    ISettlementChainParameterRegistry
} from "../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

/* ============ Deployer Imports ============ */

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

import { SettlementChainParameterRegistryDeployer } from "./deployers/SettlementChainParameterRegistryDeployer.sol";

/* ============ Source Imports ============ */

import { Proxy } from "../src/any-chain/Proxy.sol";

/* ============ Mock Imports ============ */

import { MockUnderlyingFeeToken } from "../test/utils/Mocks.sol";
import { IAppChainGateway } from "../src/app-chain/interfaces/IAppChainGateway.sol";
import { ISettlementChainGateway } from "../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { AppChainGatewayDeployer } from "./deployers/AppChainGatewayDeployer.sol";
import { SettlementChainGatewayDeployer } from "./deployers/SettlementChainGatewayDeployer.sol";

contract DeployLocalScripts is Script {
    string constant DEPLOYMENT_FILE_PATH = "./environments/anvil.json";

    string internal constant _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.minPayloadSize";

    string internal constant _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.maxPayloadSize";

    string internal constant _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.minPayloadSize";

    string internal constant _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.maxPayloadSize";

    string internal constant _PAYER_REGISTRY_SETTLER_KEY = "xmtp.payerRegistry.settler";
    string internal constant _PAYER_REGISTRY_FEE_DISTRIBUTOR_KEY = "xmtp.payerRegistry.feeDistributor";
    string internal constant _PAYER_REGISTRY_MINIMUM_DEPOSIT_KEY = "xmtp.payerRegistry.minimumDeposit";
    string internal constant _PAYER_REGISTRY_WITHDRAW_LOCK_PERIOD_KEY = "xmtp.payerRegistry.withdrawLockPeriod";

    string internal constant _RATE_REGISTRY_MESSAGE_FEE_KEY = "xmtp.rateRegistry.messageFee";
    string internal constant _RATE_REGISTRY_STORAGE_FEE_KEY = "xmtp.rateRegistry.storageFee";
    string internal constant _RATE_REGISTRY_CONGESTION_FEE_KEY = "xmtp.rateRegistry.congestionFee";
    string internal constant _RATE_REGISTRY_TARGET_RATE_PER_MINUTE_KEY = "xmtp.rateRegistry.targetRatePerMinute";

    string internal constant _NODE_REGISTRY_ADMIN_KEY = "xmtp.nodeRegistry.admin";
    string internal constant _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY = "xmtp.nodeRegistry.maxCanonicalNodes";

    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 262_144;

    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 262_144;

    uint256 internal constant _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT = 10_000000;
    uint256 internal constant _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD = 2 days;

    uint256 internal constant _RATE_REGISTRY_STARTING_MESSAGE_FEE = 100;
    uint256 internal constant _RATE_REGISTRY_STARTING_STORAGE_FEE = 200;
    uint256 internal constant _RATE_REGISTRY_STARTING_CONGESTION_FEE = 300;
    uint256 internal constant _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE = 100 * 60;

    uint256 internal constant _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES = 100;

    bytes32 internal constant _DISTRIBUTION_MANAGER_PROXY_SALT = "DistributionManager_0";
    bytes32 internal constant _FEE_TOKEN_PROXY_SALT = "FeeToken_0";
    bytes32 internal constant _GROUP_MESSAGE_BROADCASTER_PROXY_SALT = "GroupMessageBroadcaster_0";
    bytes32 internal constant _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = "IdentityUpdateBroadcaster_0";
    bytes32 internal constant _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT = "MockUnderlyingFeeToken_0";
    bytes32 internal constant _NODE_REGISTRY_PROXY_SALT = "NodeRegistry_0";
    bytes32 internal constant _PARAMETER_REGISTRY_PROXY_SALT = "ParameterRegistry_0";
    bytes32 internal constant _PAYER_REGISTRY_PROXY_SALT = "PayerRegistry_0";
    bytes32 internal constant _PAYER_REPORT_MANAGER_PROXY_SALT = "PayerReportManager_0";
    bytes32 internal constant _RATE_REGISTRY_PROXY_SALT = "RateRegistry_0";
    bytes32 internal constant _APP_CHAIN_GATEWAY_PROXY_SALT = "AppChainGateway_0";
    bytes32 internal constant _SETTLEMENT_CHAIN_GATEWAY_PROXY_SALT = "SettlementChainGateway_0";

    uint256 internal _privateKey;

    address internal _deployer;

    MockUnderlyingFeeToken internal _underlyingFeeTokenProxy;

    IFactory internal _factory;

    ISettlementChainParameterRegistry internal _parameterRegistryProxy;

    IGroupMessageBroadcaster internal _groupMessageBroadcasterProxy;
    IIdentityUpdateBroadcaster internal _identityUpdateBroadcasterProxy;

    IPayerRegistry internal _payerRegistryProxy;

    IRateRegistry internal _rateRegistryProxy;

    INodeRegistry internal _nodeRegistryProxy;

    IPayerReportManager internal _payerReportManagerProxy;

    IDistributionManager internal _distributionManagerProxy;

    IFeeToken internal _feeTokenProxy;

    IAppChainGateway internal _appChainGatewayProxy;

    ISettlementChainGateway internal _settlementChainGatewayProxy;

    function setUp() public virtual {
        _privateKey = uint256(vm.envBytes32("LOCAL_DEPLOYER_PRIVATE_KEY"));

        if (_privateKey == 0) revert("Private key not set");

        _deployer = vm.addr(_privateKey);
    }
    function deployLocal() external {
        address expectedParameterRegistryProxy_ = _getExpectedProxy(_PARAMETER_REGISTRY_PROXY_SALT);

        // ---- Factory (scoped) ----
        {
            address impl = _deployFactoryImplementation(expectedParameterRegistryProxy_);
            _factory = _deployFactoryProxy(impl);
            _initializeFactory();
        }

        // ---- Parameter Registry ----
        {
            address impl = _deploySettlementChainParameterRegistryImplementation();
            _parameterRegistryProxy = _deploySettlementChainParameterRegistryProxy(impl, _deployer);
        }

        // ---- Underlying fee token ----
        {
            address impl = _deployMockUnderlyingFeeTokenImplementation(address(_parameterRegistryProxy));
            _underlyingFeeTokenProxy = _deployMockUnderlyingFeeTokenProxy(impl);
        }

        // ---- Fee Token ----
        {
            address impl = _deployFeeTokenImplementation(
                address(_parameterRegistryProxy),
                address(_underlyingFeeTokenProxy)
            );
            _feeTokenProxy = _deployFeeTokenProxy(impl);
        }

        // ---- Payer Registry ----
        {
            address impl = _deployPayerRegistryImplementation(
                address(_parameterRegistryProxy),
                address(_feeTokenProxy)
            );
            _payerRegistryProxy = _deployPayerRegistryProxy(impl);
        }

        // ---- Rate Registry ----
        {
            address impl = _deployRateRegistryImplementation(address(_parameterRegistryProxy));
            _rateRegistryProxy = _deployRateRegistryProxy(impl);
        }

        // ---- Node Registry ----
        {
            address impl = _deployNodeRegistryImplementation(address(_parameterRegistryProxy));
            _nodeRegistryProxy = _deployNodeRegistryProxy(impl);
        }

        // ---- Payer Report Manager ----
        {
            address impl = _deployPayerReportManagerImplementation(
                address(_parameterRegistryProxy),
                address(_nodeRegistryProxy),
                address(_payerRegistryProxy)
            );
            _payerReportManagerProxy = _deployPayerReportManagerProxy(impl);
        }

        // ---- Distribution Manager ----
        {
            address impl = _deployDistributionManagerImplementation(
                address(_parameterRegistryProxy),
                address(_nodeRegistryProxy),
                address(_payerReportManagerProxy),
                address(_payerRegistryProxy),
                address(_feeTokenProxy)
            );
            _distributionManagerProxy = _deployDistributionManagerProxy(impl);
        }

        // ---- Broadcasters ----
        {
            address impl = _deployGroupMessageBroadcasterImplementation(address(_parameterRegistryProxy));
            _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(impl);
        }
        {
            address impl = _deployIdentityUpdateBroadcasterImplementation(address(_parameterRegistryProxy));
            _identityUpdateBroadcasterProxy = _deployIdentityUpdateBroadcasterProxy(impl);
        }

        // ---- Gateways ----
        {
            address impl = _deploySettlementChainGatewayImplementation(
                address(_parameterRegistryProxy),
                address(_feeTokenProxy)
            );
            _settlementChainGatewayProxy = _deploySettlementChainGatewayProxy(impl);
        }
        {
            address impl = _deployAppChainGatewayImplementation(
                address(_parameterRegistryProxy),
                address(_settlementChainGatewayProxy)
            );
            _appChainGatewayProxy = _deployAppChainGatewayProxy(impl);
        }

        // ---- Params & updates ----
        {
            _setNodeRegistryStartingParameters();
            _updateNodeRegistryStartingParameters();

            _setPayerRegistryStartingParameters();
            _updatePayerRegistryStartingParameters();

            _setRateRegistryStartingRates();
            _updateRateRegistryRates();

            _setBroadcasterStartingParameters();
            _assertBroadcasterStartingParameters();
            _updateBroadcasterStartingParameters();
        }

        console.log("Factory deployed to:", address(_factory));
        console.log("Parameter Registry deployed to:", address(_parameterRegistryProxy));
        console.log("Payer Registry deployed to:", address(_payerRegistryProxy));
        console.log("Rate Registry deployed to:", address(_rateRegistryProxy));
        console.log("Node Registry deployed to:", address(_nodeRegistryProxy));
        console.log("Payer Report Manager deployed to:", address(_payerReportManagerProxy));
        console.log("Distribution Manager deployed to:", address(_distributionManagerProxy));
        console.log("Group Message Broadcaster deployed to:", address(_groupMessageBroadcasterProxy));
        console.log("Identity Update Broadcaster deployed to:", address(_identityUpdateBroadcasterProxy));
        console.log("Settlement Chain Gateway deployed to:", address(_settlementChainGatewayProxy));
        console.log("App Chain Gateway deployed to:", address(_appChainGatewayProxy));

        _writeLocalEnvJson();
    }

    function _writeLocalEnvJson() internal {
        vm.createDir("environments", true);

        vm.serializeAddress("root", "deployer", _deployer);
        vm.serializeUint("root", "settlementChainId", block.chainid);
        vm.serializeUint("root", "appChainId", block.chainid);
        vm.serializeUint("root", "settlementChainDeploymentBlock", 0);
        vm.serializeUint("root", "appChainDeploymentBlock", 0);
        vm.serializeAddress("root", "settlementChainFactory", address(_factory));
        vm.serializeAddress("root", "appChainFactory", address(_factory));
        vm.serializeAddress("root", "settlementChainParameterRegistry", address(_parameterRegistryProxy));
        vm.serializeAddress("root", "appChainParameterRegistry", address(_parameterRegistryProxy));
        vm.serializeAddress("root", "settlementChainGateway", address(_settlementChainGatewayProxy));
        vm.serializeAddress("root", "appChainGateway", address(_appChainGatewayProxy));
        vm.serializeAddress("root", "underlyingFeeToken", address(_underlyingFeeTokenProxy));
        vm.serializeAddress("root", "feeToken", address(_feeTokenProxy));
        vm.serializeAddress("root", "payerRegistry", address(_payerRegistryProxy));
        vm.serializeAddress("root", "rateRegistry", address(_rateRegistryProxy));
        vm.serializeAddress("root", "nodeRegistry", address(_nodeRegistryProxy));
        vm.serializeAddress("root", "payerReportManager", address(_payerReportManagerProxy));
        vm.serializeAddress("root", "distributionManager", address(_distributionManagerProxy));
        vm.serializeAddress("root", "groupMessageBroadcaster", address(_groupMessageBroadcasterProxy));

        string memory json_ = vm.serializeAddress(
            "root",
            "identityUpdateBroadcaster",
            address(_identityUpdateBroadcasterProxy)
        );
        vm.writeJson(json_, DEPLOYMENT_FILE_PATH);
    }

    function checkLocalDeployment() external view {
        string memory json_ = vm.readFile(DEPLOYMENT_FILE_PATH);

        // TODO: For some or all of these, check a getter to ensure the contracts are as expected.

        if (vm.parseJsonUint(json_, ".settlementChainId") != block.chainid) revert("Settlement chain ID mismatch");
        if (vm.parseJsonUint(json_, ".appChainId") != block.chainid) revert("App chain ID mismatch");

        if (vm.parseJsonAddress(json_, ".settlementChainFactory").code.length == 0) {
            revert("Settlement chain factory does not exist");
        }

        if (vm.parseJsonAddress(json_, ".appChainFactory").code.length == 0) {
            revert("App chain factory does not exist");
        }

        if (vm.parseJsonAddress(json_, ".settlementChainParameterRegistry").code.length == 0) {
            revert("Settlement chain parameter registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".appChainParameterRegistry").code.length == 0) {
            revert("App chain parameter registry does not exist");
        }

        if (vm.parseJsonAddress(json_, ".underlyingFeeToken").code.length == 0) {
            revert("Underlying fee token does not exist");
        }

        if (vm.parseJsonAddress(json_, ".feeToken").code.length == 0) {
            revert("Fee token does not exist");
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

        if (vm.parseJsonAddress(json_, ".groupMessageBroadcaster").code.length == 0) {
            revert("Group message broadcaster does not exist");
        }

        if (vm.parseJsonAddress(json_, ".identityUpdateBroadcaster").code.length == 0) {
            revert("Identity update broadcaster does not exist");
        }
    }

    /* ============ Factory Helpers ============ */

    function _deployFactoryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = FactoryDeployer.deployImplementation(parameterRegistry_);
        vm.stopBroadcast();

        console.log("Factory Implementation Name: %s", IFactory(implementation_).contractName());
        console.log("Factory Implementation Version: %s", IFactory(implementation_).version());
    }

    function _deployFactoryProxy(address implementation_) internal returns (IFactory factory_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = FactoryDeployer.deployProxy(implementation_);
        vm.stopBroadcast();

        factory_ = IFactory(proxy_);

        if (factory_.implementation() != implementation_) revert("Factory implementation mismatch");
    }

    function _initializeFactory() internal {
        vm.startBroadcast(_privateKey);
        _factory.initialize();
        vm.stopBroadcast();
    }

    /* ============ Underlying Fee Token Helpers ============ */

    function _deployMockUnderlyingFeeTokenImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = MockUnderlyingFeeTokenDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_
        );
        vm.stopBroadcast();
    }

    function _deployMockUnderlyingFeeTokenProxy(
        address implementation_
    ) internal returns (MockUnderlyingFeeToken token_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = MockUnderlyingFeeTokenDeployer.deployProxy(
            address(_factory),
            implementation_,
            _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT
        );
        vm.stopBroadcast();

        token_ = MockUnderlyingFeeToken(proxy_);

        if (token_.implementation() != implementation_) {
            revert("Mock underlying fee token implementation mismatch");
        }
    }

    /* ============ Parameter Registry Helpers ============ */

    function _deploySettlementChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(address(_factory));
        vm.stopBroadcast();

        console.log(
            "SettlementChainParameterRegistry Implementation Name: %s",
            ISettlementChainParameterRegistry(implementation_).contractName()
        );
        console.log(
            "SettlementChainParameterRegistry Implementation Version: %s",
            ISettlementChainParameterRegistry(implementation_).version()
        );
    }

    function _deploySettlementChainParameterRegistryProxy(
        address implementation_,
        address admin_
    ) internal returns (ISettlementChainParameterRegistry registry_) {
        address[] memory admins_ = new address[](1);
        admins_[0] = admin_;

        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopBroadcast();

        registry_ = ISettlementChainParameterRegistry(proxy_);

        if (registry_.implementation() != implementation_) revert("Parameter registry implementation mismatch");
        if (!registry_.isAdmin(admin_)) revert("Admin not set correctly in parameter registry");
    }

    /* ============ Fee Token Helpers ============ */

    function _deployFeeTokenImplementation(
        address parameterRegistry_,
        address underlying_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = FeeTokenDeployer.deployImplementation(address(_factory), parameterRegistry_, underlying_);
        vm.stopBroadcast();

        console.log("FeeToken Implementation Name: %s", IFeeToken(implementation_).contractName());
        console.log("FeeToken Implementation Version: %s", IFeeToken(implementation_).version());
    }

    function _deployFeeTokenProxy(address implementation_) internal returns (IFeeToken feeToken_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = FeeTokenDeployer.deployProxy(address(_factory), implementation_, _FEE_TOKEN_PROXY_SALT);
        vm.stopBroadcast();

        feeToken_ = IFeeToken(proxy_);

        if (feeToken_.implementation() != implementation_) revert("Fee token implementation mismatch");
    }

    /* ============ Group Message Broadcaster Helpers ============ */

    function _deployGroupMessageBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_
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

        if (IGroupMessageBroadcaster(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Group message broadcaster parameter registry mismatch");
        }
    }

    function _deployGroupMessageBroadcasterProxy(
        address implementation_
    ) internal returns (IGroupMessageBroadcaster broadcaster_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            address(_factory),
            implementation_,
            _GROUP_MESSAGE_BROADCASTER_PROXY_SALT
        );
        vm.stopBroadcast();

        broadcaster_ = IGroupMessageBroadcaster(proxy_);

        if (broadcaster_.implementation() != implementation_) {
            revert("Group message broadcaster implementation mismatch");
        }
    }

    /* ============ Identity Update Broadcaster Helpers ============ */

    function _deployIdentityUpdateBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_
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

        if (IIdentityUpdateBroadcaster(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Identity update broadcaster parameter registry mismatch");
        }
    }

    function _deployIdentityUpdateBroadcasterProxy(
        address implementation_
    ) internal returns (IIdentityUpdateBroadcaster broadcaster_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            address(_factory),
            implementation_,
            _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT
        );
        vm.stopBroadcast();

        broadcaster_ = IIdentityUpdateBroadcaster(proxy_);

        if (broadcaster_.implementation() != implementation_) {
            revert("Identity update broadcaster implementation mismatch");
        }
    }

    /* ============ Broadcaster Helpers ============ */

    function _setBroadcasterStartingParameters() internal {
        string[] memory keys_ = new string[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(_GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        values_[1] = bytes32(_GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);
        values_[2] = bytes32(_IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        values_[3] = bytes32(_IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);

        vm.startBroadcast(_privateKey);
        _parameterRegistryProxy.set(keys_, values_);
        vm.stopBroadcast();

        if (_parameterRegistryProxy.get(keys_[0]) != values_[0]) {
            revert("Group message broadcaster min payload size not set correctly");
        }

        if (_parameterRegistryProxy.get(keys_[1]) != values_[1]) {
            revert("Group message broadcaster max payload size not set correctly");
        }

        if (_parameterRegistryProxy.get(keys_[2]) != values_[2]) {
            revert("Identity update broadcaster min payload size not set correctly");
        }

        if (_parameterRegistryProxy.get(keys_[3]) != values_[3]) {
            revert("Identity update broadcaster max payload size not set correctly");
        }
    }

    function _assertBroadcasterStartingParameters() internal view {
        if (
            uint256(_parameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)) !=
            _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        ) {
            revert("Group message broadcaster min payload size mismatch");
        }

        if (
            uint256(_parameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)) !=
            _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        ) {
            revert("Group message broadcaster max payload size mismatch");
        }

        if (
            uint256(_parameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)) !=
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        ) {
            revert("Identity update broadcaster min payload size mismatch");
        }

        if (
            uint256(_parameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)) !=
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        ) {
            revert("Identity update broadcaster max payload size mismatch");
        }
    }

    function _updateBroadcasterStartingParameters() internal {
        vm.startBroadcast(_privateKey);
        _groupMessageBroadcasterProxy.updateMaxPayloadSize();
        _groupMessageBroadcasterProxy.updateMinPayloadSize();
        _identityUpdateBroadcasterProxy.updateMaxPayloadSize();
        _identityUpdateBroadcasterProxy.updateMinPayloadSize();
        vm.stopBroadcast();

        if (_groupMessageBroadcasterProxy.minPayloadSize() != _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE) {
            revert("Group message broadcaster min payload size not updated correctly");
        }

        if (_groupMessageBroadcasterProxy.maxPayloadSize() != _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE) {
            revert("Group message broadcaster max payload size not updated correctly");
        }

        if (
            _identityUpdateBroadcasterProxy.minPayloadSize() != _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        ) {
            revert("Identity update broadcaster min payload size not updated correctly");
        }

        if (
            _identityUpdateBroadcasterProxy.maxPayloadSize() != _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        ) {
            revert("Identity update broadcaster max payload size not updated correctly");
        }
    }

    /* ============ Payer Registry Helpers ============ */

    function _deployPayerRegistryImplementation(
        address parameterRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = PayerRegistryDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            feeToken_
        );
        vm.stopBroadcast();

        console.log("PayerRegistry Implementation Name: %s", IPayerRegistry(implementation_).contractName());
        console.log("PayerRegistry Implementation Version: %s", IPayerRegistry(implementation_).version());

        if (IPayerRegistry(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Payer registry parameter registry mismatch");
        }

        if (IPayerRegistry(implementation_).feeToken() != feeToken_) revert("Payer registry fee token mismatch");
    }

    function _deployPayerRegistryProxy(address implementation_) internal returns (IPayerRegistry registry_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = PayerRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _PAYER_REGISTRY_PROXY_SALT
        );
        vm.stopBroadcast();

        registry_ = IPayerRegistry(proxy_);

        if (registry_.implementation() != implementation_) revert("Payer registry implementation mismatch");
    }

    function _setPayerRegistryStartingParameters() internal {
        string[] memory keys_ = new string[](4);
        keys_[0] = _PAYER_REGISTRY_SETTLER_KEY;
        keys_[1] = _PAYER_REGISTRY_FEE_DISTRIBUTOR_KEY;
        keys_[2] = _PAYER_REGISTRY_MINIMUM_DEPOSIT_KEY;
        keys_[3] = _PAYER_REGISTRY_WITHDRAW_LOCK_PERIOD_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(uint256(uint160(address(_payerReportManagerProxy))));
        values_[1] = bytes32(uint256(uint160(address(_distributionManagerProxy))));
        values_[2] = bytes32(_PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT);
        values_[3] = bytes32(_PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD);

        vm.startBroadcast(_privateKey);
        _parameterRegistryProxy.set(keys_, values_);
        vm.stopBroadcast();

        if (_parameterRegistryProxy.get(keys_[0]) != values_[0]) revert("Payer registry settler not set correctly");

        if (_parameterRegistryProxy.get(keys_[1]) != values_[1]) {
            revert("Payer registry fee distributor not set correctly");
        }

        if (_parameterRegistryProxy.get(keys_[2]) != values_[2]) {
            revert("Payer registry minimum deposit not set correctly");
        }

        if (_parameterRegistryProxy.get(keys_[3]) != values_[3]) {
            revert("Payer registry withdraw lock period not set correctly");
        }
    }

    function _updatePayerRegistryStartingParameters() internal {
        vm.startBroadcast(_privateKey);
        _payerRegistryProxy.updateSettler();
        _payerRegistryProxy.updateFeeDistributor();
        _payerRegistryProxy.updateMinimumDeposit();
        _payerRegistryProxy.updateWithdrawLockPeriod();
        vm.stopBroadcast();

        if (_payerRegistryProxy.settler() != address(_payerReportManagerProxy)) {
            revert("Payer registry settler not updated correctly");
        }

        if (_payerRegistryProxy.feeDistributor() != address(_distributionManagerProxy)) {
            revert("Payer registry fee distributor not updated correctly");
        }

        if (_payerRegistryProxy.minimumDeposit() != _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT) {
            revert("Payer registry minimum deposit not updated correctly");
        }

        if (_payerRegistryProxy.withdrawLockPeriod() != _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD) {
            revert("Payer registry withdraw lock period not updated correctly");
        }
    }

    /* ============ Rate Registry Helpers ============ */

    function _deployRateRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = RateRegistryDeployer.deployImplementation(address(_factory), parameterRegistry_);
        vm.stopBroadcast();

        console.log("RateRegistry Implementation Name: %s", IRateRegistry(implementation_).contractName());
        console.log("RateRegistry Implementation Version: %s", IRateRegistry(implementation_).version());

        if (IRateRegistry(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Rate registry parameter registry mismatch");
        }
    }

    function _deployRateRegistryProxy(address implementation_) internal returns (IRateRegistry registry_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = RateRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _RATE_REGISTRY_PROXY_SALT
        );
        vm.stopBroadcast();

        registry_ = IRateRegistry(proxy_);

        if (registry_.implementation() != implementation_) revert("Rate registry implementation mismatch");
    }

    function _setRateRegistryStartingRates() internal {
        string[] memory keys_ = new string[](4);
        keys_[0] = _RATE_REGISTRY_MESSAGE_FEE_KEY;
        keys_[1] = _RATE_REGISTRY_STORAGE_FEE_KEY;
        keys_[2] = _RATE_REGISTRY_CONGESTION_FEE_KEY;
        keys_[3] = _RATE_REGISTRY_TARGET_RATE_PER_MINUTE_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(_RATE_REGISTRY_STARTING_MESSAGE_FEE);
        values_[1] = bytes32(_RATE_REGISTRY_STARTING_STORAGE_FEE);
        values_[2] = bytes32(_RATE_REGISTRY_STARTING_CONGESTION_FEE);
        values_[3] = bytes32(_RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE);

        vm.startBroadcast(_privateKey);
        _parameterRegistryProxy.set(keys_, values_);
        vm.stopBroadcast();

        if (_parameterRegistryProxy.get(keys_[0]) != values_[0]) revert("Rate registry message fee not set correctly");
        if (_parameterRegistryProxy.get(keys_[1]) != values_[1]) revert("Rate registry storage fee not set correctly");

        if (_parameterRegistryProxy.get(keys_[2]) != values_[2]) {
            revert("Rate registry congestion fee not set correctly");
        }

        if (_parameterRegistryProxy.get(keys_[3]) != values_[3]) {
            revert("Rate registry target rate per minute not set correctly");
        }
    }

    function _updateRateRegistryRates() internal {
        vm.startBroadcast(_privateKey);
        _rateRegistryProxy.updateRates();
        vm.stopBroadcast();

        if (_rateRegistryProxy.getRatesCount() != 1) revert("Rate registry rates count mismatch");

        IRateRegistry.Rates[] memory rates_ = _rateRegistryProxy.getRates(0, 1);

        if (rates_.length != 1) revert("Rate registry rates array length mismatch");

        if (rates_[0].messageFee != _RATE_REGISTRY_STARTING_MESSAGE_FEE) revert("Rate registry message fee mismatch");
        if (rates_[0].storageFee != _RATE_REGISTRY_STARTING_STORAGE_FEE) revert("Rate registry storage fee mismatch");

        if (rates_[0].congestionFee != _RATE_REGISTRY_STARTING_CONGESTION_FEE) {
            revert("Rate registry congestion fee mismatch");
        }

        if (rates_[0].targetRatePerMinute != _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE) {
            revert("Rate registry target rate per minute mismatch");
        }

        if (rates_[0].startTime != uint64(vm.getBlockTimestamp())) revert("Rate registry start time mismatch");
    }

    /* ============ Node Registry Helpers ============ */

    function _deployNodeRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = NodeRegistryDeployer.deployImplementation(address(_factory), parameterRegistry_);
        vm.stopBroadcast();

        console.log("NodeRegistry Implementation Name: %s", INodeRegistry(implementation_).contractName());
        console.log("NodeRegistry Implementation Version: %s", INodeRegistry(implementation_).version());

        if (INodeRegistry(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Node registry parameter registry mismatch");
        }
    }

    function _deployNodeRegistryProxy(address implementation_) internal returns (INodeRegistry registry_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = NodeRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _NODE_REGISTRY_PROXY_SALT
        );
        vm.stopBroadcast();

        registry_ = INodeRegistry(proxy_);

        if (registry_.implementation() != implementation_) revert("Node registry implementation mismatch");
    }

    function _setNodeRegistryStartingParameters() internal {
        string[] memory keys_ = new string[](2);
        keys_[0] = _NODE_REGISTRY_ADMIN_KEY;
        keys_[1] = _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY;

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(uint160(_deployer)));
        values_[1] = bytes32(uint256(_NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES));

        vm.startBroadcast(_privateKey);
        _parameterRegistryProxy.set(keys_, values_);
        vm.stopBroadcast();

        if (_parameterRegistryProxy.get(keys_[0]) != values_[0]) revert("Node registry admin not set correctly");

        if (_parameterRegistryProxy.get(keys_[1]) != values_[1]) {
            revert("Node registry max canonical nodes not set correctly");
        }
    }

    function _updateNodeRegistryStartingParameters() internal {
        vm.startBroadcast(_privateKey);
        _nodeRegistryProxy.updateAdmin();
        _nodeRegistryProxy.updateMaxCanonicalNodes();
        vm.stopBroadcast();

        if (_nodeRegistryProxy.admin() != _deployer) revert("Node registry admin not updated correctly");

        if (_nodeRegistryProxy.maxCanonicalNodes() != _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES) {
            revert("Node registry max canonical nodes not updated correctly");
        }
    }

    /* ============ App Chain Gateway ======= */
    function _deployAppChainGatewayImplementation(
        address parameterRegistry_,
        address settlementChainGateway_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            settlementChainGateway_
        );
        vm.stopBroadcast();

        console.log("AppChainGateway Implementation Name: %s", IAppChainGateway(implementation_).contractName());
        console.log("AppChainGateway Implementation Version: %s", IAppChainGateway(implementation_).version());

        if (IAppChainGateway(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("App chain gateway parameter registry mismatch");
        }
        if (IAppChainGateway(implementation_).settlementChainGateway() != settlementChainGateway_) {
            revert("App chain gateway counterpart mismatch");
        }
    }

    function _deployAppChainGatewayProxy(address implementation_) internal returns (IAppChainGateway registry_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = AppChainGatewayDeployer.deployProxy(
            address(_factory),
            implementation_,
            _APP_CHAIN_GATEWAY_PROXY_SALT
        );
        vm.stopBroadcast();

        registry_ = IAppChainGateway(proxy_);

        if (registry_.implementation() != implementation_) revert("App chain gateway implementation mismatch");
    }

    /* ============ Payer Report Manager Helpers ============ */

    function _deployPayerReportManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerRegistry_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            nodeRegistry_,
            payerRegistry_
        );
        vm.stopBroadcast();

        console.log("PayerReportManager Implementation Name: %s", IPayerReportManager(implementation_).contractName());
        console.log("PayerReportManager Implementation Version: %s", IPayerReportManager(implementation_).version());

        if (IPayerReportManager(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Payer report manager parameter registry mismatch");
        }

        if (IPayerReportManager(implementation_).nodeRegistry() != nodeRegistry_) {
            revert("Payer report manager node registry mismatch");
        }

        if (IPayerReportManager(implementation_).payerRegistry() != payerRegistry_) {
            revert("Payer report manager payer registry mismatch");
        }
    }

    function _deployPayerReportManagerProxy(address implementation_) internal returns (IPayerReportManager registry_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = PayerReportManagerDeployer.deployProxy(
            address(_factory),
            implementation_,
            _PAYER_REPORT_MANAGER_PROXY_SALT
        );
        vm.stopBroadcast();

        registry_ = IPayerReportManager(proxy_);

        if (registry_.implementation() != implementation_) revert("Payer report manager implementation mismatch");
    }

    /* ============ Distribution Manager Helpers ============ */

    function _deployDistributionManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            feeToken_
        );
        vm.stopBroadcast();

        console.log(
            "DistributionManager Implementation Name: %s",
            IDistributionManager(implementation_).contractName()
        );
        console.log("DistributionManager Implementation Version: %s", IDistributionManager(implementation_).version());

        if (IDistributionManager(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Distribution manager parameter registry mismatch");
        }

        if (IDistributionManager(implementation_).nodeRegistry() != nodeRegistry_) {
            revert("Distribution manager node registry mismatch");
        }

        if (IDistributionManager(implementation_).payerReportManager() != payerReportManager_) {
            revert("Distribution manager payer report manager mismatch");
        }

        if (IDistributionManager(implementation_).payerRegistry() != payerRegistry_) {
            revert("Distribution manager payer registry mismatch");
        }

        if (IDistributionManager(implementation_).feeToken() != feeToken_) {
            revert("Distribution manager fee token mismatch");
        }
    }

    function _deployDistributionManagerProxy(
        address implementation_
    ) internal returns (IDistributionManager registry_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = DistributionManagerDeployer.deployProxy(
            address(_factory),
            implementation_,
            _DISTRIBUTION_MANAGER_PROXY_SALT
        );
        vm.stopBroadcast();

        registry_ = IDistributionManager(proxy_);

        if (registry_.implementation() != implementation_) revert("Distribution manager implementation mismatch");
    }

    function _deploySettlementChainGatewayImplementation(
        address parameterRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        address appChainGateway_ = IFactory(address(_factory)).computeProxyAddress(
            _deployer,
            _APP_CHAIN_GATEWAY_PROXY_SALT
        );

        vm.startBroadcast(_privateKey);
        (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            appChainGateway_,
            feeToken_
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

        if (ISettlementChainGateway(implementation_).parameterRegistry() != parameterRegistry_)
            revert("SC GW param reg mismatch");
        if (ISettlementChainGateway(implementation_).appChainGateway() != appChainGateway_)
            revert("SC GW counterpart mismatch");
        if (ISettlementChainGateway(implementation_).feeToken() != feeToken_) revert("SC GW fee token mismatch");
    }

    function _deploySettlementChainGatewayProxy(
        address implementation_
    ) internal returns (ISettlementChainGateway gw_) {
        vm.startBroadcast(_privateKey);
        (address proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
            address(_factory),
            implementation_,
            _SETTLEMENT_CHAIN_GATEWAY_PROXY_SALT
        );
        vm.stopBroadcast();
        gw_ = ISettlementChainGateway(proxy_);
        if (gw_.implementation() != implementation_) revert("SC GW impl mismatch");
    }

    function _getExpectedProxy(bytes32 salt_) internal view returns (address expectedProxy_) {
        // Factory must be first two creations from _deployer on this chain
        address expectedFactoryImpl_ = vm.computeCreateAddress(_deployer, 0);
        address expectedFactoryProxy_ = vm.computeCreateAddress(_deployer, 1);

        // Factory’s Initializable impl is created by the factory implementation at nonce 1
        address expectedInitializableImpl_ = vm.computeCreateAddress(expectedFactoryImpl_, 1);

        // Proxy init code is Proxy(bytecode) + abi.encode(initializableImplementation)
        bytes memory initCode_ = abi.encodePacked(type(Proxy).creationCode, abi.encode(expectedInitializableImpl_));

        // Factory proxy does the CREATE2 with salt keccak(deployer, salt_)
        expectedProxy_ = vm.computeCreate2Address(
            keccak256(abi.encode(_deployer, salt_)),
            keccak256(initCode_),
            expectedFactoryProxy_
        );

        console.log("Expected init code hash:", vm.toString(keccak256(initCode_)));
        console.log("Expected factory impl:", expectedFactoryImpl_);
        console.log("Expected factory proxy:", expectedFactoryProxy_);
        console.log("Expected initializable impl:", expectedInitializableImpl_);
        console.log("Expected proxy (salt = %s):", vm.toString(salt_));
        console.log("Result:", vm.toString(expectedProxy_));
    }
}
