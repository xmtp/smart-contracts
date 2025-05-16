// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "../../lib/forge-std/src/Test.sol";

/* ============ Source Interface Imports ============ */

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IGroupMessageBroadcaster } from "../../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../../src/settlement-chain/interfaces/IRateRegistry.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import {
    ISettlementChainParameterRegistry
} from "../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

/* ============ Deployer Imports ============ */

import { DistributionManagerDeployer } from "../../script/deployers/DistributionManagerDeployer.sol";
import { FactoryDeployer } from "../../script/deployers/FactoryDeployer.sol";
import { GroupMessageBroadcasterDeployer } from "../../script/deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "../../script/deployers/IdentityUpdateBroadcasterDeployer.sol";
import { NodeRegistryDeployer } from "../../script/deployers/NodeRegistryDeployer.sol";
import { PayerRegistryDeployer } from "../../script/deployers/PayerRegistryDeployer.sol";
import { PayerReportManagerDeployer } from "../../script/deployers/PayerReportManagerDeployer.sol";
import { RateRegistryDeployer } from "../../script/deployers/RateRegistryDeployer.sol";
import { SettlementChainGatewayDeployer } from "../../script/deployers/SettlementChainGatewayDeployer.sol";

import {
    SettlementChainParameterRegistryDeployer
} from "../../script/deployers/SettlementChainParameterRegistryDeployer.sol";

/* ============ Test Interface Imports ============ */

import { IERC20Like } from "./Interfaces.sol";

contract DeploymentTests is Test {
    address internal constant _APPCHAIN_NATIVE_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    bytes internal constant _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.minPayloadSize";

    bytes internal constant _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.maxPayloadSize";

    bytes internal constant _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.minPayloadSize";

    bytes internal constant _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.maxPayloadSize";

    bytes internal constant _PAYER_REGISTRY_SETTLER_KEY = "xmtp.payerRegistry.settler";
    bytes internal constant _PAYER_REGISTRY_FEE_DISTRIBUTOR_KEY = "xmtp.payerRegistry.feeDistributor";
    bytes internal constant _PAYER_REGISTRY_MINIMUM_DEPOSIT_KEY = "xmtp.payerRegistry.minimumDeposit";
    bytes internal constant _PAYER_REGISTRY_WITHDRAW_LOCK_PERIOD_KEY = "xmtp.payerRegistry.withdrawLockPeriod";

    bytes internal constant _RATE_REGISTRY_MESSAGE_FEE_KEY = "xmtp.rateRegistry.messageFee";
    bytes internal constant _RATE_REGISTRY_STORAGE_FEE_KEY = "xmtp.rateRegistry.storageFee";
    bytes internal constant _RATE_REGISTRY_CONGESTION_FEE_KEY = "xmtp.rateRegistry.congestionFee";
    bytes internal constant _RATE_REGISTRY_TARGET_RATE_PER_MINUTE_KEY = "xmtp.rateRegistry.targetRatePerMinute";

    bytes internal constant _NODE_REGISTRY_ADMIN_KEY = "xmtp.nodeRegistry.admin";
    bytes internal constant _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY = "xmtp.nodeRegistry.maxCanonicalNodes";

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

    bytes32 internal constant _PARAMETER_REGISTRY_PROXY_SALT = bytes32(uint256(0));
    bytes32 internal constant _GATEWAY_PROXY_SALT = bytes32(uint256(1));
    bytes32 internal constant _GROUP_MESSAGE_BROADCASTER_PROXY_SALT = bytes32(uint256(2));
    bytes32 internal constant _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = bytes32(uint256(3));
    bytes32 internal constant _PAYER_REGISTRY_PROXY_SALT = bytes32(uint256(4));
    bytes32 internal constant _RATE_REGISTRY_PROXY_SALT = bytes32(uint256(5));
    bytes32 internal constant _NODE_REGISTRY_PROXY_SALT = bytes32(uint256(6));
    bytes32 internal constant _PAYER_REPORT_MANAGER_PROXY_SALT = bytes32(uint256(7));
    bytes32 internal constant _DISTRIBUTION_MANAGER_PROXY_SALT = bytes32(uint256(8));

    address internal _admin = makeAddr("admin");
    address internal _alice = makeAddr("alice");

    uint256 internal _baseForkId;

    IFactory internal _settlementChainFactory;

    ISettlementChainParameterRegistry internal _settlementChainParameterRegistryProxy;

    ISettlementChainGateway internal _settlementChainGatewayProxy;

    IGroupMessageBroadcaster internal _groupMessageBroadcasterProxy;
    IIdentityUpdateBroadcaster internal _identityUpdateBroadcasterProxy;

    IPayerRegistry internal _payerRegistryProxy;

    IRateRegistry internal _rateRegistryProxy;

    INodeRegistry internal _nodeRegistryProxy;

    IPayerReportManager internal _payerReportManagerProxy;

    IDistributionManager internal _distributionManagerProxy;

    function setUp() external {
        _baseForkId = vm.createFork("base_sepolia");
    }

    function test_deployProtocol_oneChain() external {
        // Deploy the Factory on the base (settlement) chain.
        _settlementChainFactory = _deploySettlementChainFactory();

        // Deploy the Parameter Registry on the base (settlement) chain.
        address settlementChainParameterRegistryImplementation_ = _deploySettlementChainParameterRegistryImplementation();

        // The admin of the Parameter Registry on the base (settlement) chain is the global admin.
        _settlementChainParameterRegistryProxy = _deploySettlementChainParameterRegistryProxy(
            settlementChainParameterRegistryImplementation_,
            _admin
        );

        // Deploy the Payer Registry on the base (settlement) chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(
            address(_settlementChainParameterRegistryProxy),
            _APPCHAIN_NATIVE_TOKEN
        );

        _payerRegistryProxy = _deployPayerRegistryProxy(payerRegistryImplementation_);

        // Deploy the Rate Registry on the base (settlement) chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(
            address(_settlementChainParameterRegistryProxy)
        );

        _rateRegistryProxy = _deployRateRegistryProxy(rateRegistryImplementation_);

        // Deploy the Node Registry on the base (settlement) chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(
            address(_settlementChainParameterRegistryProxy)
        );

        _nodeRegistryProxy = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        // Deploy the Payer Report Manager on the base (settlement) chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            address(_settlementChainParameterRegistryProxy),
            address(_nodeRegistryProxy),
            address(_payerRegistryProxy)
        );

        _payerReportManagerProxy = _deployPayerReportManagerProxy(payerReportManagerImplementation_);

        // Deploy the Distribution Manager on the base (settlement) chain.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            address(_settlementChainParameterRegistryProxy),
            address(_nodeRegistryProxy),
            address(_payerReportManagerProxy),
            address(_payerRegistryProxy),
            _APPCHAIN_NATIVE_TOKEN
        );

        _distributionManagerProxy = _deployDistributionManagerProxy(distributionManagerImplementation_);

        // Deploy the Group Message Broadcaster on the base (settlement) chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            address(_settlementChainParameterRegistryProxy)
        );

        _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        // Deploy the Identity Update Broadcaster on the base (settlement) chain.
        address identityUpdateBroadcasterImplementation_ = _deployIdentityUpdateBroadcasterImplementation(
            address(_settlementChainParameterRegistryProxy)
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

    function _deploySettlementChainFactory() internal returns (IFactory factory_) {
        vm.selectFork(_baseForkId);
        return _deployFactory();
    }

    function _deployFactory() internal returns (IFactory factory_) {
        vm.startPrank(_admin);
        factory_ = IFactory(FactoryDeployer.deploy());
        vm.stopPrank();
    }

    /* ============ Parameter Registry Helpers ============ */

    function _deploySettlementChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(
            address(_settlementChainFactory)
        );
        vm.stopPrank();
    }

    function _deploySettlementChainParameterRegistryProxy(
        address implementation_,
        address admin_
    ) internal returns (ISettlementChainParameterRegistry registry_) {
        vm.selectFork(_baseForkId);

        address[] memory admins_ = new address[](1);
        admins_[0] = admin_;

        vm.startPrank(_admin);
        (address proxy_, , ) = SettlementChainParameterRegistryDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _PARAMETER_REGISTRY_PROXY_SALT,
            admins_
        );
        vm.stopPrank();

        registry_ = ISettlementChainParameterRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
        assertTrue(registry_.isAdmin(admin_));
    }

    /* ============ Group Message Broadcaster Helpers ============ */

    function _deployGroupMessageBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IGroupMessageBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployGroupMessageBroadcasterProxy(
        address implementation_
    ) internal returns (IGroupMessageBroadcaster broadcaster_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            address(_settlementChainFactory),
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
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IIdentityUpdateBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployIdentityUpdateBroadcasterProxy(
        address implementation_
    ) internal returns (IIdentityUpdateBroadcaster broadcaster_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT
        );
        vm.stopPrank();

        broadcaster_ = IIdentityUpdateBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Broadcaster Helpers ============ */

    function _setBroadcasterStartingParameters() internal {
        vm.selectFork(_baseForkId);

        bytes[] memory keys_ = new bytes[](4);
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
        _settlementChainParameterRegistryProxy.set(keys_, values_);

        assertEq(_settlementChainParameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _assertBroadcasterStartingParameters() internal {
        vm.selectFork(_baseForkId);

        assertEq(
            uint256(_settlementChainParameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_settlementChainParameterRegistryProxy.get(_GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_settlementChainParameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY)),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(_settlementChainParameterRegistryProxy.get(_IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY)),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );
    }

    function _updateBroadcasterStartingParameters() internal {
        vm.selectFork(_baseForkId);

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
        address token_
    ) internal returns (address implementation_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = PayerRegistryDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_,
            token_
        );
        vm.stopPrank();

        assertEq(IPayerRegistry(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerRegistry(implementation_).token(), token_);
    }

    function _deployPayerRegistryProxy(address implementation_) internal returns (IPayerRegistry registry_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = PayerRegistryDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _PAYER_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IPayerRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setPayerRegistryStartingParameters() internal {
        vm.selectFork(_baseForkId);

        bytes[] memory keys_ = new bytes[](4);
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
        _settlementChainParameterRegistryProxy.set(keys_, values_);

        assertEq(_settlementChainParameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _updatePayerRegistryStartingParameters() internal {
        vm.selectFork(_baseForkId);

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
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = RateRegistryDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(IRateRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployRateRegistryProxy(address implementation_) internal returns (IRateRegistry registry_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = RateRegistryDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _RATE_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IRateRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setRateRegistryStartingRates() internal {
        vm.selectFork(_baseForkId);

        bytes[] memory keys_ = new bytes[](4);
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
        _settlementChainParameterRegistryProxy.set(keys_, values_);

        assertEq(_settlementChainParameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[1]), values_[1]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[2]), values_[2]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[3]), values_[3]);
    }

    function _updateRateRegistryRates() internal {
        vm.selectFork(_baseForkId);

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
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = NodeRegistryDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_
        );
        vm.stopPrank();

        assertEq(INodeRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployNodeRegistryProxy(address implementation_) internal returns (INodeRegistry registry_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = NodeRegistryDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _NODE_REGISTRY_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = INodeRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setNodeRegistryStartingParameters() internal {
        vm.selectFork(_baseForkId);

        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = _NODE_REGISTRY_ADMIN_KEY;
        keys_[1] = _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY;

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(uint160(_admin)));
        values_[1] = bytes32(uint256(_NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES));

        vm.prank(_admin);
        _settlementChainParameterRegistryProxy.set(keys_, values_);

        assertEq(_settlementChainParameterRegistryProxy.get(keys_[0]), values_[0]);
        assertEq(_settlementChainParameterRegistryProxy.get(keys_[1]), values_[1]);
    }

    function _updateNodeRegistryStartingParameters() internal {
        vm.selectFork(_baseForkId);

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
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
            address(_settlementChainFactory),
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
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = PayerReportManagerDeployer.deployProxy(
            address(_settlementChainFactory),
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
        address token_
    ) internal returns (address implementation_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            address(_settlementChainFactory),
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            token_
        );
        vm.stopPrank();

        assertEq(IDistributionManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IDistributionManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IDistributionManager(implementation_).payerReportManager(), payerReportManager_);
        assertEq(IDistributionManager(implementation_).payerRegistry(), payerRegistry_);
        assertEq(IDistributionManager(implementation_).token(), token_);
    }

    function _deployDistributionManagerProxy(
        address implementation_
    ) internal returns (IDistributionManager registry_) {
        vm.selectFork(_baseForkId);

        vm.startPrank(_admin);
        (address proxy_, , ) = DistributionManagerDeployer.deployProxy(
            address(_settlementChainFactory),
            implementation_,
            _DISTRIBUTION_MANAGER_PROXY_SALT
        );
        vm.stopPrank();

        registry_ = IDistributionManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Token Helpers ============ */

    function _giveTokens(address recipient_, uint256 amount_) internal {
        vm.selectFork(_baseForkId);
        deal(_APPCHAIN_NATIVE_TOKEN, recipient_, amount_);
    }

    function _approveTokens(address account_, address spender_, uint256 amount_) internal {
        vm.selectFork(_baseForkId);
        vm.prank(account_);
        IERC20Like(_APPCHAIN_NATIVE_TOKEN).approve(spender_, amount_);
    }
}
