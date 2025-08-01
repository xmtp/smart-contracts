// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, Vm, console } from "../../lib/forge-std/src/Test.sol";

/* ============ Source Library Imports ============ */

import { AddressAliasHelper } from "../../src/libraries/AddressAliasHelper.sol";

/* ============ Source Library Imports ============ */

import { ParameterKeys } from "../../src/libraries/ParameterKeys.sol";

/* ============ Source Interface Imports ============ */

import { IAppChainGateway } from "../../src/app-chain/interfaces/IAppChainGateway.sol";
import { IDepositSplitter } from "../../src/settlement-chain/interfaces/IDepositSplitter.sol";
import { IDistributionManager } from "../../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IFeeToken } from "../../src/settlement-chain/interfaces/IFeeToken.sol";
import { IGroupMessageBroadcaster } from "../../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../../src/settlement-chain/interfaces/IRateRegistry.sol";
import { ISettlementChainGateway } from "../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import {
    ISettlementChainParameterRegistry
} from "../../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

/* ============ Deployer Imports ============ */

import { AppChainGatewayDeployer } from "../../script/deployers/AppChainGatewayDeployer.sol";
import { AppChainParameterRegistryDeployer } from "../../script/deployers/AppChainParameterRegistryDeployer.sol";
import { DepositSplitterDeployer } from "../../script/deployers/DepositSplitterDeployer.sol";
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
import { SettlementChainGatewayDeployer } from "../../script/deployers/SettlementChainGatewayDeployer.sol";

import {
    SettlementChainParameterRegistryDeployer
} from "../../script/deployers/SettlementChainParameterRegistryDeployer.sol";

/* ============ Source Imports ============ */

import { Migrator } from "../../src/any-chain/Migrator.sol";
import { Proxy } from "../../src/any-chain/Proxy.sol";

/* ============ Test Interface Imports ============ */

import { IERC20Like, IBridgeLike, IERC20InboxLike, IArbRetryableTxPrecompileLike } from "./Interfaces.sol";

/* ============ Test Contract Imports ============ */

import { MockUnderlyingFeeToken } from "../utils/Mocks.sol";

abstract contract DeployTests is Test {
    error MessageDataHashMismatch(uint256 messageNumber_);
    error UnexpectedInbox(address inbox_);
    error UnexpectedMessageKind(uint8 kind_);

    address internal constant _APPCHAIN_RETRYABLE_TX_PRECOMPILE = 0x000000000000000000000000000000000000006E;

    uint8 internal constant _RETRYABLE_TICKET_KIND = 9;

    uint256 internal constant _TX_STIPEND = 21_000;
    uint256 internal constant _GAS_PER_BRIDGED_KEY = 75_000;

    address internal constant _ADMIN = 0x560469CBb7D1E29c7d56EfE765B21FbBaC639dC7;
    address internal constant _DEPLOYER = 0xD940Dd30F750162c12086C6dc68507F7e8C480B4;

    string internal constant _SETTLEMENT_CHAIN_GATEWAY_INBOX_KEY = "xmtp.settlementChainGateway.inbox";

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

    string internal constant _PAYER_REPORT_MANAGER_PROTOCOL_FEE_RATE_KEY = "xmtp.payerReportManager.protocolFeeRate";

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

    uint256 internal constant _PAYER_REPORT_MANAGER_STARTING_PROTOCOL_FEE_RATE = 100;

    bytes32 internal constant _FEE_TOKEN_PROXY_SALT = "FeeToken_0";
    bytes32 internal constant _PARAMETER_REGISTRY_PROXY_SALT = "ParameterRegistry_0";
    bytes32 internal constant _GATEWAY_PROXY_SALT = "Gateway_0_0";

    address internal _alice = makeAddr("alice");

    address internal _settlementChainInboxToAppchain;
    address internal _settlementChainBridge;

    address internal _factory;
    address internal _feeToken;
    address internal _gateway;
    address internal _parameterRegistry;
    address internal _underlyingFeeToken;

    uint256 internal _appChainGasPrice = 2_000_000_000; // 2 gwei per gas.

    bytes32 internal _distributionManagerProxySalt;
    bytes32 internal _groupMessageBroadcasterProxySalt;
    bytes32 internal _identityUpdateBroadcasterProxySalt;
    bytes32 internal _nodeRegistryProxySalt;
    bytes32 internal _payerRegistryProxySalt;
    bytes32 internal _payerReportManagerProxySalt;
    bytes32 internal _rateRegistryProxySalt;

    uint256 internal _settlementChainForkId;
    uint256 internal _appChainForkId;

    uint256 internal _settlementChainId;
    uint256 internal _appChainId;

    IDepositSplitter internal _depositSplitter;
    IDistributionManager internal _distributionManager;
    IGroupMessageBroadcaster internal _groupMessageBroadcaster;
    IIdentityUpdateBroadcaster internal _identityUpdateBroadcaster;
    INodeRegistry internal _nodeRegistry;
    IPayerRegistry internal _payerRegistry;
    IPayerReportManager internal _payerReportManager;
    IRateRegistry internal _rateRegistry;

    function setUp() public virtual {
        vm.recordLogs();
    }

    /* ============ Factory Helpers ============ */

    function _deploySettlementChainFactoryImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);
        return _deployFactoryImplementation(parameterRegistry_);
    }

    function _deployAppChainFactoryImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);
        return _deployFactoryImplementation(parameterRegistry_);
    }

    function _deployFactoryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        implementation_ = FactoryDeployer.getImplementationViaFactory(_factory, parameterRegistry_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = FactoryDeployer.deployImplementationViaFactory(_factory, parameterRegistry_);
            vm.stopPrank();
        }

        assertEq(IFactory(implementation_).parameterRegistry(), parameterRegistry_);
    }

    /* ============ Parameter Registry Helpers ============ */

    function _deploySettlementChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = SettlementChainParameterRegistryDeployer.getImplementation(_factory);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(_factory);
            vm.stopPrank();
        }
    }

    function _deployAppChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        implementation_ = AppChainParameterRegistryDeployer.getImplementation(_factory);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = AppChainParameterRegistryDeployer.deployImplementation(_factory);
            vm.stopPrank();
        }
    }

    /* ============ Mock Underlying Fee Token Helpers ============ */

    function _deployMockUnderlyingFeeTokenImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = MockUnderlyingFeeTokenDeployer.getImplementation(_factory, parameterRegistry_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = MockUnderlyingFeeTokenDeployer.deployImplementation(_factory, parameterRegistry_);
            vm.stopPrank();
        }

        assertEq(MockUnderlyingFeeToken(implementation_).parameterRegistry(), parameterRegistry_);
    }

    /* ============ Fee Token Helpers ============ */

    function _deployFeeTokenImplementation(
        address parameterRegistry_,
        address underlyingFeeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = FeeTokenDeployer.getImplementation(_factory, parameterRegistry_, underlyingFeeToken_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = FeeTokenDeployer.deployImplementation(
                _factory,
                parameterRegistry_,
                underlyingFeeToken_
            );
            vm.stopPrank();
        }

        assertEq(IFeeToken(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IFeeToken(implementation_).underlying(), underlyingFeeToken_);
    }

    /* ============ Gateway Helpers ============ */

    function _deploySettlementChainGatewayImplementation(
        address parameterRegistry_,
        address appChainGateway_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = SettlementChainGatewayDeployer.getImplementation(
            _factory,
            parameterRegistry_,
            appChainGateway_,
            feeToken_
        );

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = SettlementChainGatewayDeployer.deployImplementation(
                _factory,
                parameterRegistry_,
                appChainGateway_,
                feeToken_
            );
            vm.stopPrank();
        }

        assertEq(ISettlementChainGateway(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(ISettlementChainGateway(implementation_).appChainGateway(), appChainGateway_);
        assertEq(ISettlementChainGateway(implementation_).feeToken(), feeToken_);
    }

    function _deployAppChainGatewayImplementation(
        address parameterRegistry_,
        address settlementChainGateway_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        implementation_ = AppChainGatewayDeployer.getImplementation(
            _factory,
            parameterRegistry_,
            settlementChainGateway_
        );

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
                _factory,
                parameterRegistry_,
                settlementChainGateway_
            );
            vm.stopPrank();
        }

        assertEq(IAppChainGateway(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IAppChainGateway(implementation_).settlementChainGateway(), settlementChainGateway_);

        assertEq(
            IAppChainGateway(implementation_).settlementChainGatewayAlias(),
            AddressAliasHelper.toAlias(settlementChainGateway_)
        );
    }

    function _deploySettlementChainGatewayProxy(
        address implementation_
    ) internal returns (ISettlementChainGateway gateway_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = SettlementChainGatewayDeployer.deployProxy(
            _factory,
            implementation_,
            _GATEWAY_PROXY_SALT
        );
        vm.stopPrank();

        gateway_ = ISettlementChainGateway(proxy_);

        assertEq(gateway_.implementation(), implementation_);
    }

    function _deployAppChainGatewayProxy(address implementation_) internal returns (IAppChainGateway gateway_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = AppChainGatewayDeployer.deployProxy(_factory, implementation_, _GATEWAY_PROXY_SALT);
        vm.stopPrank();

        gateway_ = IAppChainGateway(proxy_);

        assertEq(gateway_.implementation(), implementation_);
    }

    function _setInboxParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](1);
        keys_[0] = ParameterKeys.combineKeyComponents(
            _SETTLEMENT_CHAIN_GATEWAY_INBOX_KEY,
            ParameterKeys.uint256ToKeyComponent(_appChainId)
        );

        bytes32[] memory values_ = new bytes32[](1);
        values_[0] = bytes32(uint256(uint160(_settlementChainInboxToAppchain)));

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[0]), values_[0]);
    }

    function _updateInboxParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.prank(_ADMIN);
        ISettlementChainGateway(_gateway).updateInbox(_appChainId);
    }

    /* ============ Group Message Broadcaster Helpers ============ */

    function _deployGroupMessageBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        implementation_ = GroupMessageBroadcasterDeployer.getImplementation(_factory, parameterRegistry_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = GroupMessageBroadcasterDeployer.deployImplementation(_factory, parameterRegistry_);
            vm.stopPrank();
        }

        assertEq(IGroupMessageBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployGroupMessageBroadcasterProxy(
        address implementation_
    ) internal returns (IGroupMessageBroadcaster broadcaster_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = GroupMessageBroadcasterDeployer.deployProxy(
            _factory,
            implementation_,
            _groupMessageBroadcasterProxySalt
        );
        vm.stopPrank();

        broadcaster_ = IGroupMessageBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Identity Update Broadcaster Helpers ============ */

    function _deployIdentityUpdateBroadcasterImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_appChainForkId);

        implementation_ = IdentityUpdateBroadcasterDeployer.getImplementation(_factory, parameterRegistry_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = IdentityUpdateBroadcasterDeployer.deployImplementation(_factory, parameterRegistry_);
            vm.stopPrank();
        }

        assertEq(IIdentityUpdateBroadcaster(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployIdentityUpdateBroadcasterProxy(
        address implementation_
    ) internal returns (IIdentityUpdateBroadcaster broadcaster_) {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = IdentityUpdateBroadcasterDeployer.deployProxy(
            _factory,
            implementation_,
            _identityUpdateBroadcasterProxySalt
        );
        vm.stopPrank();

        broadcaster_ = IIdentityUpdateBroadcaster(proxy_);

        assertEq(broadcaster_.implementation(), implementation_);
    }

    /* ============ Broadcaster Helpers ============ */

    function _setBroadcasterStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

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

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[1]), values_[1]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[2]), values_[2]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[3]), values_[3]);
    }

    function _bridgeBroadcasterStartingParameters(uint256 chainId_, uint256 gasPrice_) internal {
        string[] memory keys_ = new string[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        _sendParameters(_alice, chainId_, keys_, gasPrice_);
    }

    function _assertBroadcasterStartingParameters() internal {
        vm.selectFork(_appChainForkId);

        assertEq(
            uint256(
                ISettlementChainParameterRegistry(_parameterRegistry).get(
                    _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY
                )
            ),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(
                ISettlementChainParameterRegistry(_parameterRegistry).get(
                    _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY
                )
            ),
            _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );

        assertEq(
            uint256(
                ISettlementChainParameterRegistry(_parameterRegistry).get(
                    _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY
                )
            ),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE
        );

        assertEq(
            uint256(
                ISettlementChainParameterRegistry(_parameterRegistry).get(
                    _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY
                )
            ),
            _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE
        );
    }

    function _updateBroadcasterStartingParameters() internal {
        vm.selectFork(_appChainForkId);

        vm.startPrank(_alice);
        _groupMessageBroadcaster.updateMaxPayloadSize();
        _groupMessageBroadcaster.updateMinPayloadSize();
        _identityUpdateBroadcaster.updateMaxPayloadSize();
        _identityUpdateBroadcaster.updateMinPayloadSize();
        vm.stopPrank();

        assertEq(_groupMessageBroadcaster.minPayloadSize(), _GROUP_MESSAGE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        assertEq(_groupMessageBroadcaster.maxPayloadSize(), _GROUP_MESSAGE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);
        assertEq(_identityUpdateBroadcaster.minPayloadSize(), _IDENTITY_UPDATE_BROADCASTER_STARTING_MIN_PAYLOAD_SIZE);
        assertEq(_identityUpdateBroadcaster.maxPayloadSize(), _IDENTITY_UPDATE_BROADCASTER_STARTING_MAX_PAYLOAD_SIZE);
    }

    /* ============ Payer Registry Helpers ============ */

    function _deployPayerRegistryImplementation(
        address parameterRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = PayerRegistryDeployer.getImplementation(_factory, parameterRegistry_, feeToken_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = PayerRegistryDeployer.deployImplementation(_factory, parameterRegistry_, feeToken_);
            vm.stopPrank();
        }

        assertEq(IPayerRegistry(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerRegistry(implementation_).feeToken(), feeToken_);
    }

    function _deployPayerRegistryProxy(address implementation_) internal returns (IPayerRegistry registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = PayerRegistryDeployer.deployProxy(_factory, implementation_, _payerRegistryProxySalt);
        vm.stopPrank();

        registry_ = IPayerRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setPayerRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](4);
        keys_[0] = _PAYER_REGISTRY_SETTLER_KEY;
        keys_[1] = _PAYER_REGISTRY_FEE_DISTRIBUTOR_KEY;
        keys_[2] = _PAYER_REGISTRY_MINIMUM_DEPOSIT_KEY;
        keys_[3] = _PAYER_REGISTRY_WITHDRAW_LOCK_PERIOD_KEY;

        bytes32[] memory values_ = new bytes32[](4);
        values_[0] = bytes32(uint256(uint160(address(_payerReportManager))));
        values_[1] = bytes32(uint256(uint160(address(_distributionManager))));
        values_[2] = bytes32(_PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT);
        values_[3] = bytes32(_PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[1]), values_[1]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[2]), values_[2]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[3]), values_[3]);
    }

    function _updatePayerRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_alice);
        _payerRegistry.updateSettler();
        _payerRegistry.updateFeeDistributor();
        _payerRegistry.updateMinimumDeposit();
        _payerRegistry.updateWithdrawLockPeriod();
        vm.stopPrank();

        assertEq(_payerRegistry.settler(), address(_payerReportManager));
        assertEq(_payerRegistry.feeDistributor(), address(_distributionManager));
        assertEq(_payerRegistry.minimumDeposit(), _PAYER_REGISTRY_STARTING_MINIMUM_DEPOSIT);
        assertEq(_payerRegistry.withdrawLockPeriod(), _PAYER_REGISTRY_STARTING_WITHDRAW_LOCK_PERIOD);
    }

    /* ============ Rate Registry Helpers ============ */

    function _deployRateRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = RateRegistryDeployer.getImplementation(_factory, parameterRegistry_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = RateRegistryDeployer.deployImplementation(_factory, parameterRegistry_);
            vm.stopPrank();
        }

        assertEq(IRateRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployRateRegistryProxy(address implementation_) internal returns (IRateRegistry registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = RateRegistryDeployer.deployProxy(_factory, implementation_, _rateRegistryProxySalt);
        vm.stopPrank();

        registry_ = IRateRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setRateRegistryStartingRates() internal {
        vm.selectFork(_settlementChainForkId);

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

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[1]), values_[1]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[2]), values_[2]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[3]), values_[3]);
    }

    function _updateRateRegistryRates() internal {
        vm.selectFork(_settlementChainForkId);

        vm.prank(_alice);
        _rateRegistry.updateRates();

        assertEq(_rateRegistry.getRatesCount(), 1);

        IRateRegistry.Rates[] memory rates_ = _rateRegistry.getRates(0, 1);

        assertEq(rates_.length, 1);

        assertEq(rates_[0].messageFee, _RATE_REGISTRY_STARTING_MESSAGE_FEE);
        assertEq(rates_[0].storageFee, _RATE_REGISTRY_STARTING_STORAGE_FEE);
        assertEq(rates_[0].congestionFee, _RATE_REGISTRY_STARTING_CONGESTION_FEE);
        assertEq(rates_[0].targetRatePerMinute, _RATE_REGISTRY_STARTING_TARGET_RATE_PER_MINUTE);
        assertEq(rates_[0].startTime, uint64(vm.getBlockTimestamp()));
    }

    /* ============ Node Registry Helpers ============ */

    function _deployNodeRegistryImplementation(address parameterRegistry_) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = NodeRegistryDeployer.getImplementation(_factory, parameterRegistry_);

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = NodeRegistryDeployer.deployImplementation(_factory, parameterRegistry_);
            vm.stopPrank();
        }

        assertEq(INodeRegistry(implementation_).parameterRegistry(), parameterRegistry_);
    }

    function _deployNodeRegistryProxy(address implementation_) internal returns (INodeRegistry registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = NodeRegistryDeployer.deployProxy(_factory, implementation_, _nodeRegistryProxySalt);
        vm.stopPrank();

        registry_ = INodeRegistry(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setNodeRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](2);
        keys_[0] = _NODE_REGISTRY_ADMIN_KEY;
        keys_[1] = _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY;

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(uint160(_ADMIN)));
        values_[1] = bytes32(_NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[0]), values_[0]);
        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[1]), values_[1]);
    }

    function _updateNodeRegistryStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_alice);
        _nodeRegistry.updateAdmin();
        _nodeRegistry.updateMaxCanonicalNodes();
        vm.stopPrank();

        assertEq(_nodeRegistry.admin(), _ADMIN);
        assertEq(_nodeRegistry.maxCanonicalNodes(), _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES);
    }

    /* ============ Payer Report Manager Helpers ============ */

    function _deployPayerReportManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerRegistry_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = PayerReportManagerDeployer.getImplementation(
            _factory,
            parameterRegistry_,
            nodeRegistry_,
            payerRegistry_
        );

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = PayerReportManagerDeployer.deployImplementation(
                _factory,
                parameterRegistry_,
                nodeRegistry_,
                payerRegistry_
            );
            vm.stopPrank();
        }

        assertEq(IPayerReportManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IPayerReportManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IPayerReportManager(implementation_).payerRegistry(), payerRegistry_);
    }

    function _deployPayerReportManagerProxy(address implementation_) internal returns (IPayerReportManager registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = PayerReportManagerDeployer.deployProxy(
            _factory,
            implementation_,
            _payerReportManagerProxySalt
        );
        vm.stopPrank();

        registry_ = IPayerReportManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    function _setPayerReportManagerStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        string[] memory keys_ = new string[](1);
        keys_[0] = _PAYER_REPORT_MANAGER_PROTOCOL_FEE_RATE_KEY;

        bytes32[] memory values_ = new bytes32[](1);
        values_[0] = bytes32(_PAYER_REPORT_MANAGER_STARTING_PROTOCOL_FEE_RATE);

        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(keys_, values_);

        assertEq(ISettlementChainParameterRegistry(_parameterRegistry).get(keys_[0]), values_[0]);
    }

    function _updatePayerReportManagerStartingParameters() internal {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_alice);
        _payerReportManager.updateProtocolFeeRate();
        vm.stopPrank();

        assertEq(_payerReportManager.protocolFeeRate(), _PAYER_REPORT_MANAGER_STARTING_PROTOCOL_FEE_RATE);
    }

    /* ============ Distribution Manager Helpers ============ */

    function _deployDistributionManagerImplementation(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address feeToken_
    ) internal returns (address implementation_) {
        vm.selectFork(_settlementChainForkId);

        implementation_ = DistributionManagerDeployer.getImplementation(
            _factory,
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            feeToken_
        );

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = DistributionManagerDeployer.deployImplementation(
                _factory,
                parameterRegistry_,
                nodeRegistry_,
                payerReportManager_,
                payerRegistry_,
                feeToken_
            );
            vm.stopPrank();
        }

        assertEq(IDistributionManager(implementation_).parameterRegistry(), parameterRegistry_);
        assertEq(IDistributionManager(implementation_).nodeRegistry(), nodeRegistry_);
        assertEq(IDistributionManager(implementation_).payerReportManager(), payerReportManager_);
        assertEq(IDistributionManager(implementation_).payerRegistry(), payerRegistry_);
        assertEq(IDistributionManager(implementation_).feeToken(), feeToken_);
    }

    function _deployDistributionManagerProxy(
        address implementation_
    ) internal returns (IDistributionManager registry_) {
        vm.selectFork(_settlementChainForkId);

        vm.startPrank(_DEPLOYER);
        (address proxy_, , ) = DistributionManagerDeployer.deployProxy(
            _factory,
            implementation_,
            _distributionManagerProxySalt
        );
        vm.stopPrank();

        registry_ = IDistributionManager(proxy_);

        assertEq(registry_.implementation(), implementation_);
    }

    /* ============ Deposit Splitter Helpers ============ */

    function _deployDepositSplitter(
        address feeTokenProxy_,
        address payerRegistryProxy_,
        address settlementChainGatewayProxy_,
        uint256 appChainId_
    ) internal returns (IDepositSplitter splitter_) {
        address implementation_ = DepositSplitterDeployer.getImplementation(
            _factory,
            feeTokenProxy_,
            payerRegistryProxy_,
            settlementChainGatewayProxy_,
            appChainId_
        );

        if (implementation_.code.length == 0) {
            vm.startPrank(_DEPLOYER);
            (implementation_, ) = DepositSplitterDeployer.deployImplementation(
                _factory,
                feeTokenProxy_,
                payerRegistryProxy_,
                settlementChainGatewayProxy_,
                appChainId_
            );
            vm.stopPrank();
        }

        splitter_ = IDepositSplitter(implementation_);

        assertEq(splitter_.feeToken(), feeTokenProxy_);
        assertEq(splitter_.payerRegistry(), payerRegistryProxy_);
        assertEq(splitter_.settlementChainGateway(), settlementChainGatewayProxy_);
        assertEq(splitter_.appChainId(), appChainId_);
    }

    /* ============ Migration Helpers ============ */

    function _deploySettlementChainMigrator(
        address proxy_,
        address toImplementation_
    ) internal returns (address migrator_) {
        vm.selectFork(_settlementChainForkId);

        return _deployMigratorForProxy(proxy_, toImplementation_);
    }

    function _deployAppChainMigrator(address proxy_, address toImplementation_) internal returns (address migrator_) {
        vm.selectFork(_appChainForkId);

        return _deployMigratorForProxy(proxy_, toImplementation_);
    }

    function _deployMigratorForProxy(address proxy_, address toImplementation_) internal returns (address migrator_) {
        string memory key_ = _getMigratorParameterKey(proxy_);

        // If the proxy does not have a migrator parameter key, then it is not migratable this way (or at all).
        if (bytes(key_).length == 0) return address(0);

        address currentImplementation_ = IMigratable(proxy_).implementation();

        // If the current implementation is already the same as the to implementation, do nothing.
        if (currentImplementation_ == toImplementation_) return address(0);

        // If the to implementation does not have the same migrator parameter key, then it is incompatible.
        assertEq(key_, _getMigratorParameterKey(toImplementation_), "IncompatibleImplementation");

        vm.startPrank(_DEPLOYER);

        // Deploy a migrator to specifically migrate proxies from the current implementation to the new implementation.
        migrator_ = _deployMigrator(currentImplementation_, toImplementation_);

        vm.stopPrank();
    }

    function _deployMigrator(
        address fromImplementation_,
        address toImplementation_
    ) internal returns (address migrator_) {
        assertNotEq(fromImplementation_, address(0));
        assertNotEq(toImplementation_, address(0));

        bytes memory constructorArguments_ = abi.encode(fromImplementation_, toImplementation_);
        bytes memory creationCode_ = abi.encodePacked(type(Migrator).creationCode, constructorArguments_);

        migrator_ = IFactory(_factory).computeImplementationAddress(creationCode_);

        if (migrator_.code.length == 0) {
            migrator_ = IFactory(_factory).deployImplementation(creationCode_);
        }

        assertEq(Migrator(migrator_).fromImplementation(), fromImplementation_);
        assertEq(Migrator(migrator_).toImplementation(), toImplementation_);

        return migrator_;
    }

    function _getMigratorParameterKey(address proxy_) internal view returns (string memory key_) {
        (bool success_, bytes memory data_) = proxy_.staticcall(abi.encodeWithSignature("migratorParameterKey()"));

        // Return empty string if the proxy doesn't implement `migratorParameterKey()`
        return success_ ? abi.decode(data_, (string)) : "";
    }

    function _migrateOnSettlementChain(address proxy_, address migrator_) internal {
        vm.selectFork(_settlementChainForkId);

        if (migrator_ == address(0)) return;

        string memory key_ = _getMigratorParameterKey(proxy_);

        vm.startPrank(_ADMIN);

        // Set the migrator parameter key to the migrator address.
        ISettlementChainParameterRegistry(_parameterRegistry).set(key_, bytes32(uint256(uint160(migrator_))));

        // Migrate the proxy to the to implementation.
        IMigratable(proxy_).migrate();

        // Set the migrator parameter key back to 0.
        ISettlementChainParameterRegistry(_parameterRegistry).set(key_, bytes32(0));

        vm.stopPrank();

        assertEq(IMigratable(proxy_).implementation(), Migrator(migrator_).toImplementation());
        assertEq(_getMigratorParameterKey(proxy_), key_);
    }

    function _migrateOnAppChain(address proxy_, address migrator_) internal {
        vm.selectFork(_appChainForkId);

        if (migrator_ == address(0)) return;

        string memory key_ = _getMigratorParameterKey(proxy_);

        vm.selectFork(_settlementChainForkId);

        // Set the migrator parameter key to the migrator address.
        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(key_, bytes32(uint256(uint160(migrator_))));

        string[] memory keys_ = new string[](1);
        keys_[0] = key_;

        _sendParameters(_ADMIN, _appChainId, keys_, _appChainGasPrice);
        _handleQueuedBridgeEvents();

        vm.selectFork(_appChainForkId);

        // Migrate the proxy to the to implementation.
        vm.prank(_ADMIN);
        IMigratable(proxy_).migrate();

        assertEq(IMigratable(proxy_).implementation(), Migrator(migrator_).toImplementation());
        assertEq(_getMigratorParameterKey(proxy_), key_);

        vm.selectFork(_settlementChainForkId);

        // Set the migrator parameter key back to 0.
        vm.prank(_ADMIN);
        ISettlementChainParameterRegistry(_parameterRegistry).set(key_, bytes32(0));
    }

    /* ============ Token Helpers ============ */

    function _giveUnderlyingFeeTokens(address recipient_, uint256 amount_) internal virtual;

    function _approveTokens(address token_, address account_, address spender_, uint256 amount_) internal {
        vm.selectFork(_settlementChainForkId);
        vm.prank(account_);
        IERC20Like(token_).approve(spender_, amount_);
    }

    function _mintFeeTokens(address account_, uint256 amount_) internal {
        _approveTokens(_underlyingFeeToken, account_, _feeToken, amount_);

        vm.selectFork(_settlementChainForkId);

        vm.prank(account_);
        IFeeToken(_feeToken).deposit(amount_);
    }

    /* ============ Bridge Helpers ============ */

    function _sendParameters(address account_, uint256 chainId_, string[] memory keys_, uint256 gasPrice_) internal {
        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * 4);
        uint256 cost_ = (gasPrice_ * gasLimit_) / 1e12; // 1e6 / 1e18 = 1 / 1e12

        _giveUnderlyingFeeTokens(account_, cost_);
        _mintFeeTokens(account_, cost_);
        _approveTokens(_feeToken, account_, _gateway, cost_);

        vm.selectFork(_settlementChainForkId);

        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = chainId_;

        vm.prank(account_);
        ISettlementChainGateway(_gateway).sendParameters(chainIds_, keys_, gasLimit_, gasPrice_, cost_);
    }

    function _handleQueuedBridgeEvents() internal {
        vm.selectFork(_settlementChainForkId);

        Vm.Log[] memory logs_ = vm.getRecordedLogs();

        for (uint256 index_; index_ < logs_.length; ++index_) {
            Vm.Log memory log_ = logs_[index_];

            if (log_.emitter != _settlementChainBridge) continue; // Not a bridge event.

            if (log_.topics[0] != IBridgeLike.MessageDelivered.selector) continue; // Not a `MessageDelivered` event.

            // Try to match the `MessageDelivered` event to a `InboxMessageDelivered` event in `logs_`, and handle it.
            _handleMessageDeliveredEvent(log_, logs_);
        }
    }

    function _handleMessageDeliveredEvent(Vm.Log memory messageDeliveredLog_, Vm.Log[] memory logs_) internal {
        (
            uint256 messageIndex_,
            address inbox_,
            uint8 kind_,
            address sender_,
            bytes32 messageDataHash_,
            uint256 baseFeeL1_
        ) = _decodeMessageDeliveredEvent(messageDeliveredLog_);

        if (kind_ != _RETRYABLE_TICKET_KIND) return; // Not a retryable ticket. TODO: Handle other kinds of messages.

        for (uint256 index_; index_ < logs_.length; ++index_) {
            Vm.Log memory log_ = logs_[index_];

            if (log_.emitter != inbox_) continue;

            if (log_.topics[0] != IERC20InboxLike.InboxMessageDelivered.selector) continue;

            // Parse the `InboxMessageDelivered` event and handle it.
            // NOTE: `sender_` should already be aliased at this point, at least for retryable tickets.
            _handleInboxMessageDeliveredEvent(inbox_, messageIndex_, kind_, sender_, messageDataHash_, log_);
        }
    }

    function _handleInboxMessageDeliveredEvent(
        address inbox_,
        uint256 messageIndex_,
        uint8 kind_,
        address sender_,
        bytes32 messageDataHash_,
        Vm.Log memory inboxMessageDeliveredLog_
    ) internal {
        _selectForkForDelivery(inbox_);

        (uint256 messageNumber_, bytes memory data_) = _decodeInboxMessageDeliveredEvent(inboxMessageDeliveredLog_);

        if (messageNumber_ != messageIndex_) return; // Not the expected message number.

        if (keccak256(data_) != messageDataHash_) revert MessageDataHashMismatch(messageNumber_);

        _handleMessageDelivery(kind_, sender_, messageNumber_, data_);
    }

    function _selectForkForDelivery(address inbox_) internal {
        if (inbox_ == _settlementChainInboxToAppchain) {
            vm.selectFork(_appChainForkId);
        } else {
            revert UnexpectedInbox(inbox_);
        }
    }

    function _handleMessageDelivery(uint8 kind_, address sender_, uint256 messageNumber_, bytes memory data_) internal {
        if (kind_ == _RETRYABLE_TICKET_KIND) {
            _handleRetryableTicket(sender_, messageNumber_, data_);
        } else {
            revert UnexpectedMessageKind(kind_);
        }
    }

    function _handleRetryableTicket(address sender_, uint256 messageNumber_, bytes memory data_) internal {
        (
            address retryTo_,
            ,
            uint256 deposit_,
            uint256 maxSubmissionFee_,
            address refundAddress_,
            ,
            uint256 gasLimit_,
            uint256 gasFeeCap_,
            bytes memory retryData_
        ) = _decodeMessageData(data_);

        // NOTE: Cannot do this due to `InvalidFEOpcode` error as foundry likely doesn't support `ArbOS` opcodes.
        // _submitRetryable(
        //     sender_,
        //     bytes32(messageNumber_),
        //     deposit_,
        //     gasFeeCap_,
        //     uint64(gasLimit_),
        //     maxSubmissionFee_,
        //     refundAddress_,
        //     retryTo_,
        //     retryData_
        // );

        _call(sender_, retryTo_, retryData_);
    }

    function _submitRetryable(
        address account_,
        bytes32 requestId_,
        uint256 deposit_,
        uint256 gasFeeCap_,
        uint64 gasLimit_,
        uint256 maxSubmissionFee_,
        address refundAddress_,
        address retryTo_,
        bytes memory retryData_
    ) internal {
        vm.prank(account_);
        IArbRetryableTxPrecompileLike(_APPCHAIN_RETRYABLE_TX_PRECOMPILE).submitRetryable(
            requestId_,
            0,
            deposit_,
            0,
            gasFeeCap_,
            gasLimit_,
            maxSubmissionFee_,
            refundAddress_,
            refundAddress_,
            retryTo_,
            retryData_
        );
    }

    function _call(address sender_, address to_, bytes memory data_) internal {
        vm.prank(sender_);
        (bool success_, ) = to_.call(data_);
        assertTrue(success_);
    }

    /* ============ Bridge Event Decoders ============ */

    function _decodeMessageDeliveredEvent(
        Vm.Log memory log_
    )
        internal
        pure
        returns (
            uint256 messageIndex_,
            address inbox_,
            uint8 kind_,
            address sender_,
            bytes32 messageDataHash_,
            uint256 baseFeeL1_
        )
    {
        messageIndex_ = uint256(bytes32(log_.topics[1]));

        (inbox_, kind_, sender_, messageDataHash_, baseFeeL1_, ) = abi.decode(
            log_.data,
            (address, uint8, address, bytes32, uint256, uint64)
        );
    }

    function _decodeInboxMessageDeliveredEvent(
        Vm.Log memory log_
    ) internal pure returns (uint256 messageNum_, bytes memory data_) {
        messageNum_ = uint256(bytes32(log_.topics[1]));
        data_ = abi.decode(log_.data, (bytes));
    }

    function _decodeMessageData(
        bytes memory messageData_
    )
        internal
        pure
        returns (
            address to_,
            uint256 l2CallValue_,
            uint256 amount_,
            uint256 maxSubmissionCost_,
            address excessFeeRefundAddress_,
            address callValueRefundAddress_,
            uint256 gasLimit_,
            uint256 maxFeePerGas_,
            bytes memory data_
        )
    {
        assembly {
            to_ := mload(add(messageData_, 0x20))
            l2CallValue_ := mload(add(messageData_, 0x40))
            amount_ := mload(add(messageData_, 0x60))
            maxSubmissionCost_ := mload(add(messageData_, 0x80))
            excessFeeRefundAddress_ := mload(add(messageData_, 0xa0))
            callValueRefundAddress_ := mload(add(messageData_, 0xc0))
            gasLimit_ := mload(add(messageData_, 0xe0))
            maxFeePerGas_ := mload(add(messageData_, 0x100))
            let dataLength_ := mload(add(messageData_, 0x120))
            data_ := add(messageData_, 0x120)
            mstore(data_, dataLength_)
        }
    }

    /* ============ Expected Address Getters ============ */

    function _expectedGatewayProxy() internal returns (address expectedGatewayProxy_) {
        vm.selectFork(_settlementChainForkId);
        return IFactory(_factory).computeProxyAddress(_DEPLOYER, _GATEWAY_PROXY_SALT);
    }
}
