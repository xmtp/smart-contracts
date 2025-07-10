// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

/* ============ Source Interface Imports ============ */

import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IFeeToken } from "../../src/settlement-chain/interfaces/IFeeToken.sol";
import { IGroupMessageBroadcaster } from "../../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../../src/settlement-chain/interfaces/IRateRegistry.sol";

import {
    ISettlementChainParameterRegistry
} from "../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

/* ============ Deployer Imports ============ */

import { DistributionManagerDeployer } from "../../script/deployers/DistributionManagerDeployer.sol";
import { FactoryDeployer } from "../../script/deployers/FactoryDeployer.sol";
import { FeeTokenDeployer } from "../../script/deployers/FeeTokenDeployer.sol";
import { GroupMessageBroadcasterDeployer } from "../../script/deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "../../script/deployers/IdentityUpdateBroadcasterDeployer.sol";
import { MockUnderlyingFeeTokenDeployer } from "../../script/deployers/MockUnderlyingFeeTokenDeployer.sol";
import { NodeRegistryDeployer } from "../../script/deployers/NodeRegistryDeployer.sol";
import { PayerRegistryDeployer } from "../../script/deployers/PayerRegistryDeployer.sol";
import { PayerReportManagerDeployer } from "../../script/deployers/PayerReportManagerDeployer.sol";
import { RateRegistryDeployer } from "../../script/deployers/RateRegistryDeployer.sol";

import {
    SettlementChainParameterRegistryDeployer
} from "../../script/deployers/SettlementChainParameterRegistryDeployer.sol";

/* ============ Test Interface Imports ============ */

import { IERC20Like } from "./Interfaces.sol";

/* ============ Mock Imports ============ */

import { MockUnderlyingFeeToken } from "../utils/Mocks.sol";

contract DeployLocalTests is Test {
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
    uint256 internal constant _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE = 78;
    uint256 internal constant _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE = 4_194_304;

    uint256 internal constant _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT = 10_000000;
    uint256 internal constant _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD = 2 days;

    uint256 internal constant _RATE_REGISTRY_STARTING_MESSAGE_FEE = 100;
    uint256 internal constant _RATE_REGISTRY_STARTING_STORAGE_FEE = 200;
    uint256 internal constant _RATE_REGISTRY_STARTING_CONGESTION_FEE = 300;
    uint256 internal constant _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE = 100 * 60;

    uint256 internal constant _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES = 100;

    bytes32 internal constant _DISTRIBUTION_MANAGER_PROXY_SALT = "DistributionManager_0";
    bytes32 internal constant _FEE_TOKEN_PROXY_SALT = "FeeToken_0";
    bytes32 internal constant _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT = "MockUnderlyingFeeToken_0";
    bytes32 internal constant _GROUP_MESSAGE_BROADCASTER_PROXY_SALT = "GroupMessageBroadcaster_0";
    bytes32 internal constant _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = "IdentityUpdateBroadcaster_0";
    bytes32 internal constant _NODE_REGISTRY_PROXY_SALT = "NodeRegistry_0";
    bytes32 internal constant _PARAMETER_REGISTRY_PROXY_SALT = "ParameterRegistry_0";
    bytes32 internal constant _PAYER_REGISTRY_PROXY_SALT = "PayerRegistry_0";
    bytes32 internal constant _PAYER_REPORT_MANAGER_PROXY_SALT = "PayerReportManager_0";
    bytes32 internal constant _RATE_REGISTRY_PROXY_SALT = "RateRegistry_0";

    address internal _deployer;

    address internal _admin = makeAddr("admin");
    address internal _alice = makeAddr("alice");

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

    function setUp() external {
        // Get the deployer address from the environment variable, which will produce addresses that can be expected in
        // a local deployment. If not set, make a deployer address.
        _deployer = vm.envOr("LOCAL_DEPLOYER", makeAddr("deployer"));
    }

    function test_deployLocalProtocol() external {
        // Deploy the Factory.
        _factory = _deployFactory();

        // Deploy the Parameter Registry.
        address parameterRegistryImplementation_ = _deploySettlementChainParameterRegistryImplementation();

        // The admin of the Parameter Registry is the global admin.
        _parameterRegistryProxy = _deploySettlementChainParameterRegistryProxy(
            parameterRegistryImplementation_,
            _admin
        );

        // Deploy the mock underlying fee token.
        address underlyingFeeTokenImplementation_ = _deployMockUnderlyingFeeTokenImplementation(
            address(_parameterRegistryProxy)
        );

        _underlyingFeeTokenProxy = _deployMockUnderlyingFeeTokenProxy(underlyingFeeTokenImplementation_);

        // Deploy the Fee Token.
        address feeTokenImplementation_ = _deployFeeTokenImplementation(
            address(_parameterRegistryProxy),
            address(_underlyingFeeTokenProxy)
        );

        _feeTokenProxy = _deployFeeTokenProxy(feeTokenImplementation_);

        // Deploy the Payer Registry.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(
            address(_parameterRegistryProxy),
            address(_feeTokenProxy)
        );

        _payerRegistryProxy = _deployPayerRegistryProxy(payerRegistryImplementation_);

        // Deploy the Rate Registry.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(address(_parameterRegistryProxy));

        _rateRegistryProxy = _deployRateRegistryProxy(rateRegistryImplementation_);

        // Deploy the Node Registry.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(address(_parameterRegistryProxy));

        _nodeRegistryProxy = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        // Deploy the Payer Report Manager.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            address(_parameterRegistryProxy),
            address(_nodeRegistryProxy),
            address(_payerRegistryProxy)
        );

        _payerReportManagerProxy = _deployPayerReportManagerProxy(payerReportManagerImplementation_);

        // Deploy the Distribution Manager.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            address(_parameterRegistryProxy),
            address(_nodeRegistryProxy),
            address(_payerReportManagerProxy),
            address(_payerRegistryProxy),
            address(_feeTokenProxy)
        );

        _distributionManagerProxy = _deployDistributionManagerProxy(distributionManagerImplementation_);

        // Deploy the Group Message Broadcaster.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            address(_parameterRegistryProxy)
        );

        _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        // Deploy the Identity Update Broadcaster.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            address(_parameterRegistryProxy)
        );

        _identityUpdateBroadcasterProxy = _deployIdentityUpdateBroadcasterProxy(
            identityUpdateBroadcasterImplementation_
        );

        // Set and update the parameters as needed for the Node Registry.
        _setNodeRegistryStartingParameters();
        _updateNodeRegistryStartingParameters();

        // Set and update the parameters as needed for the Payer Registry.
        _setPayerRegistryStartingParameters();
        _updatePayerRegistryStartingParameters();

        // Set and update the parameters as needed for the Rate Registry.
        _setRateRegistryStartingRates();
        _updateRateRegistryRates();

        // Set, update, and assert the parameters as needed for the Group Message Broadcaster and Identity Update
        // Broadcaster.
        _setBroadcasterStartingParameters();
        _assertBroadcasterStartingParameters();
        _updateBroadcasterStartingParameters();
    }

    /* ============ Factory Helpers ============ */

    function _deployFactory() internal returns (IFactory factory_) {
        vm.startPrank(_deployer);
        factory_ = IFactory(FactoryDeployer.deploy());
        vm.stopPrank();
    }

    /* ============ Parameter Registry Helpers ============ */

    function _deploySettlementChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(address(_factory));
        vm.stopPrank();
    }

    function _deploySettlementChainParameterRegistryProxy(
        address implementation_,
        address admin_
    ) internal returns (ISettlementChainParameterRegistry registry_) {
        address[] memory admins_ = new address[](1);
        admins_[0] = admin_;

        vm.startPrank(_deployer);
        (address proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        registry_ = ISettlementChainParameterRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
        assertTrue(registry_.isAdmin(admin_));
    }

    /* ============ Mock Underlying Fee Token Helpers ============ */

    function _deployMockUnderlyingFeeTokenImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = MockUnderlyingFeeTokenDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(MockUnderlyingFeeToken(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployMockUnderlyingFeeTokenProxy(
        address implementation_
    ) internal returns (MockUnderlyingFeeToken token_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = MockUnderlyingFeeTokenDeployer.deployProxy(
            address(_factory),
            implementation_,
            _MOCK_UNDERLYING_FEE_TOKEN_PROXY_SALT
        );
        vm.stopPrank();

        token_ = MockUnderlyingFeeToken(proxy_);

        assertEq(token_.implementation(), implementation_);
    }

    /* ============ Fee Token Helpers ============ */

    function _deployFeeTokenImplementation(
        address parameterRegistry_,
        address underlying_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = FeeTokenDeployer.deployImplementation(address(_factory), parameterRegistry_, underlying_);
        vm.stopPrank();

        assertEq(IFeeToken(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IFeeToken(implementation_).underlying(), underlying_);
    }

    function _deployFeeTokenProxy(address implementation_) internal returns (IFeeToken feeToken_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = FeeTokenDeployer.deployProxy(address(_factory), implementation_, _FEE_TOKEN_PROXY_SALT);
        vm.stopPrank();

        feeToken_ = IFeeToken(proxy_);

        assertEq(feeToken_.implementation(), implementation_);
    }

    /* ============ Group Message Broadcaster Helpers ============ */

    function _deployGroupMessageBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IGroupMessageBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployGroupMessageBroadcasterProxy(
        address implementation_
    ) internal returns (IGroupMessageBroadcaster broadcaster_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            address(_factory),
            implementation_,
            _GROUP_MESSAGE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IGroupMessageBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Identity Update Broadcaster Helpers ============ */

    function _deployIdentityUpdateBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IIdentityUpdateBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployIdentityUpdateBroadcasterProxy(
        address implementation_
    ) internal returns (IIdentityUpdateBroadcaster broadcaster_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            address(_factory),
            implementation_,
            _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IIdentityUpdateBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
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

        vm.prank(_admin);
        _parameterRegistryProxy.set(keys_, values_);

        assertEq(_parameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_parameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_parameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_parameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _assertBroadcasterStartingParameters() internal view {
        assertEq(
            uint256(_parameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_parameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_parameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_parameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );
    }

    function _updateBroadcasterStartingParameters() internal {
        vm.startPrank(_alice);
        _groupMessageBroadcasterProxy.updateMaxPayloadSize();
        _groupMessageBroadcasterProxy.updateMinPayloadSize();
        _identityUpdateBroadcasterProxy.updateMaxPayloadSize();
        _identityUpdateBroadcasterProxy.updateMinPayloadSize();
        vm.stopPrank();

        assertEq(_groupMessageBroadcasterProxy.minPayloadSize(), _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);

        assertEq(_groupMessageBroadcasterProxy.maxPayloadSize(), _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);

        assertEq(
            _identityUpdateBroadcasterProxy.minPayloadSize(),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            _identityUpdateBroadcasterProxy.maxPayloadSize(),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );
    }

    /* ============ Payer Registry Helpers ============ */

    function _deployPayerRegistryImplementation(
        address parameterRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = PayerRegistryDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            feeToken_
        );
        vm.stopPrank();

        assertEq(IPayerRegistry(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerRegistry(implementation_).feeToken(), feeToken_);
    }

    function _deployPayerRegistryProxy(address implementation_) internal returns (IPayerRegistry registry_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = PayerRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _PAYER_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IPayerRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
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

        vm.prank(_admin);
        _parameterRegistryProxy.set(keys_, values_);

        assertEq(_parameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_parameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_parameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_parameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _updatePayerRegistryStartingParameters() internal {
        vm.startPrank(_alice);
        _payerRegistryProxy.updateSettler();
        _payerRegistryProxy.updateFeeDistributor();
        _payerRegistryProxy.updateMinimumDeposit();
        _payerRegistryProxy.updateWithdrawLockPeriod();
        vm.stopPrank();

        assertEq(_payerRegistryProxy.settler(), address(_payerReportManagerProxy));
        assertEq(_payerRegistryProxy.feeDistributor(), address(_distributionManagerProxy));
        assertEq(_payerRegistryProxy.minimumDeposit(), _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT);
        assertEq(_payerRegistryProxy.withdrawLockPeriod(), _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD);
    }

    /* ============ Rate Registry Helpers ============ */

    function _deployRateRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = RateRegistryDeployer.deployImplementation(address(_factory), parameterRegistry_);
        vm.stopPrank();

        assertEq(IRateRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployRateRegistryProxy(address implementation_) internal returns (IRateRegistry registry_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = RateRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _RATE_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IRateRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
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

        vm.prank(_admin);
        _parameterRegistryProxy.set(keys_, values_);

        assertEq(_parameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_parameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_parameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_parameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _updateRateRegistryRates() internal {
        vm.prank(_alice);
        _rateRegistryProxy.updateRates();

        assertEq(_rateRegistryProxy.getRatesCount(), 1);

        IRateRegistry.Rates[] memory rates_ = _rateRegistryProxy.getRates(0, 1);

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, _RATE_REGISTRY_STARTING_MESSAGE_FEE);
        assertEq(rates_[0].storageFee, _RATE_REGISTRY_STARTING_STORAGE_FEE);
        assertEq(rates_[0].congestionFee, _RATE_REGISTRY_STARTING_CONGESTION_FEE);
        assertEq(rates_[0].targetRatePerMinute, _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE);
        assertEq(rates_[0].startTime, uint64(vm.getBlockTimestamp()));
    }

    /* ============ Node Registry Helpers ============ */

    function _deployNodeRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = NodeRegistryDeployer.deployImplementation(address(_factory), parameterRegistry_);
        vm.stopPrank();

        assertEq(INodeRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployNodeRegistryProxy(address implementation_) internal returns (INodeRegistry registry_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = NodeRegistryDeployer.deployProxy(
            address(_factory),
            implementation_,
            _NODE_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = INodeRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setNodeRegistryStartingParameters() internal {
        string[] memory keys_ = new string[](2);
        keys_[0] = _NODE_REGISTRY_ADMIN_KEY;
        keys_[1] = _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY;

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(uint160(_admin)));
        values_[1] = bytes32(uint256(_NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES));

        vm.prank(_admin);
        _parameterRegistryProxy.set(keys_, values_);

        assertEq(_parameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_parameterRegistryProxy.get(keys_[1]), values_[1]);
    }

    function _updateNodeRegistryStartingParameters() internal {
        vm.startPrank(_alice);
        _nodeRegistryProxy.updateAdmin();
        _nodeRegistryProxy.updateMaxCanonicalNodes();
        vm.stopPrank();

        assertEq(_nodeRegistryProxy.admin(), _admin);
        assertEq(_nodeRegistryProxy.maxCanonicalNodes(), _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES);
    }

    /* ============ Payer Report Manager Helpers ============ */

    function _deployPayerReportManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerRegistry_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            nodeRegistry_,
            payerRegistry_
        );
        vm.stopPrank();

        assertEq(IPayerReportManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerReportManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IPayerReportManager(implementation_).payerRegistry(), payerRegistry_);
    }

    function _deployPayerReportManagerProxy(address implementation_) internal returns (IPayerReportManager registry_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = PayerReportManagerDeployer.deployProxy(
            address(_factory),
            implementation_,
            _PAYER_REPORT_MANAGER_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IPayerReportManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Distribution Manager Helpers ============ */

    function _deployDistributionManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.startPrank(_deployer);
        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            feeToken_
        );
        vm.stopPrank();

        assertEq(IDistributionManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IDistributionManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IDistributionManager(implementation_).payerReportManager(), payerReportManager_);
        assertEq(IDistributionManager(implementation_).payerRegistry(), payerRegistry_);
        assertEq(IDistributionManager(implementation_).feeToken(), feeToken_);
    }

    function _deployDistributionManagerProxy(
        address implementation_
    ) internal returns (IDistributionManager registry_) {
        vm.startPrank(_deployer);
        (address proxy_, , ) = DistributionManagerDeployer.deployProxy(
            address(_factory),
            implementation_,
            _DISTRIBUTION_MANAGER_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IDistributionManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Token Helpers ============ */

    function _giveUnderlying(address recipient_, uint256 amount_) internal {
        _underlyingFeeTokenProxy.mint(recipient_, amount_);
    }

    function _approveTokens(address token_, address account_, address spender_, uint256 amount_) internal {
        vm.prank(account_);
        IERC20Like(token_).approve(spender_, amount_);
    }
}
