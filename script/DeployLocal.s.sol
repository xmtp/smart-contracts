pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";

/* ============ Source Interface Imports ============ */

import { IERC1967 } from "../src/abstract/interfaces/IERC1967.sol";
import { IDistributionManager } from "../src/settlement-chain/interfaces/IDistributionManager.sol";
import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
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
import { GroupMessageBroadcasterDeployer } from "./deployers/GroupMessageBroadcasterDeployer.sol";
import { IdentityUpdateBroadcasterDeployer } from "./deployers/IdentityUpdateBroadcasterDeployer.sol";
import { NodeRegistryDeployer } from "./deployers/NodeRegistryDeployer.sol";
import { PayerRegistryDeployer } from "./deployers/PayerRegistryDeployer.sol";
import { PayerReportManagerDeployer } from "./deployers/PayerReportManagerDeployer.sol";
import { RateRegistryDeployer } from "./deployers/RateRegistryDeployer.sol";

import { SettlementChainParameterRegistryDeployer } from "./deployers/SettlementChainParameterRegistryDeployer.sol";

contract DeployLocal is Script {
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
    bytes32 internal constant _GROUP_MESSAGE_BROADCASTER_PROXY_SALT = bytes32(uint256(2));
    bytes32 internal constant _IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = bytes32(uint256(3));
    bytes32 internal constant _PAYER_REGISTRY_PROXY_SALT = bytes32(uint256(4));
    bytes32 internal constant _RATE_REGISTRY_PROXY_SALT = bytes32(uint256(5));
    bytes32 internal constant _NODE_REGISTRY_PROXY_SALT = bytes32(uint256(6));
    bytes32 internal constant _PAYER_REPORT_MANAGER_PROXY_SALT = bytes32(uint256(7));
    bytes32 internal constant _DISTRIBUTION_MANAGER_PROXY_SALT = bytes32(uint256(8));

    uint256 internal _privateKey;

    address internal _admin;

    IFactory internal _factory;

    ISettlementChainParameterRegistry internal _parameterRegistryProxy;

    IGroupMessageBroadcaster internal _groupMessageBroadcasterProxy;
    IIdentityUpdateBroadcaster internal _identityUpdateBroadcasterProxy;

    IPayerRegistry internal _payerRegistryProxy;

    IRateRegistry internal _rateRegistryProxy;

    INodeRegistry internal _nodeRegistryProxy;

    IPayerReportManager internal _payerReportManagerProxy;

    IDistributionManager internal _distributionManagerProxy;

    function setUp() public virtual {
        _privateKey = uint256(vm.envBytes32("LOCAL_DEPLOY_PRIVATE_KEY"));

        if (_privateKey == 0) revert("Private key not set");

        _admin = vm.addr(_privateKey);
    }

    function run() external {
        // Deploy the Factory on the base (settlement) chain.
        _factory = _deploySettlementChainFactory();

        // Deploy the Parameter Registry on the base (settlement) chain.
        address settlementChainParameterRegistryImplementation_ = _deploySettlementChainParameterRegistryImplementation();

        // The admin of the Parameter Registry on the base (settlement) chain is the global admin.
        _parameterRegistryProxy = _deploySettlementChainParameterRegistryProxy(
            settlementChainParameterRegistryImplementation_,
            _admin
        );

        // Deploy the Payer Registry on the base (settlement) chain.
        address payerRegistryImplementation_ = _deployPayerRegistryImplementation(
            address(_parameterRegistryProxy),
            _APPCHAIN_NATIVE_TOKEN
        );

        _payerRegistryProxy = _deployPayerRegistryProxy(payerRegistryImplementation_);

        // Deploy the Rate Registry on the base (settlement) chain.
        address rateRegistryImplementation_ = _deployRateRegistryImplementation(address(_parameterRegistryProxy));

        _rateRegistryProxy = _deployRateRegistryProxy(rateRegistryImplementation_);

        // Deploy the Node Registry on the base (settlement) chain.
        address nodeRegistryImplementation_ = _deployNodeRegistryImplementation(address(_parameterRegistryProxy));

        _nodeRegistryProxy = _deployNodeRegistryProxy(nodeRegistryImplementation_);

        // Deploy the Payer Report Manager on the base (settlement) chain.
        address payerReportManagerImplementation_ = _deployPayerReportManagerImplementation(
            address(_parameterRegistryProxy),
            address(_nodeRegistryProxy),
            address(_payerRegistryProxy)
        );

        _payerReportManagerProxy = _deployPayerReportManagerProxy(payerReportManagerImplementation_);

        // Deploy the Distribution Manager on the base (settlement) chain.
        address distributionManagerImplementation_ = _deployDistributionManagerImplementation(
            address(_parameterRegistryProxy),
            address(_nodeRegistryProxy),
            address(_payerReportManagerProxy),
            address(_payerRegistryProxy),
            _APPCHAIN_NATIVE_TOKEN
        );

        _distributionManagerProxy = _deployDistributionManagerProxy(distributionManagerImplementation_);

        // Deploy the Group Message Broadcaster on the base (settlement) chain.
        address groupMessageBroadcasterImplementation_ = _deployGroupMessageBroadcasterImplementation(
            address(_parameterRegistryProxy)
        );

        _groupMessageBroadcasterProxy = _deployGroupMessageBroadcasterProxy(groupMessageBroadcasterImplementation_);

        // Deploy the Identity Update Broadcaster on the base (settlement) chain.
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

        // Log Out Deployed Contracts
        console.log("Factory deployed to:", address(_factory));
        console.log("Parameter Registry deployed to:", address(_parameterRegistryProxy));
        console.log("Payer Registry deployed to:", address(_payerRegistryProxy));
        console.log("Rate Registry deployed to:", address(_rateRegistryProxy));
        console.log("Node Registry deployed to:", address(_nodeRegistryProxy));
        console.log("Payer Report Manager deployed to:", address(_payerReportManagerProxy));
        console.log("Distribution Manager deployed to:", address(_distributionManagerProxy));
        console.log("Group Message Broadcaster deployed to:", address(_groupMessageBroadcasterProxy));
        console.log("Identity Update Broadcaster deployed to:", address(_identityUpdateBroadcasterProxy));
    }

    /* ============ Factory Helpers ============ */

    function _deploySettlementChainFactory() internal returns (IFactory factory_) {
        return _deployFactory();
    }

    function _deployFactory() internal returns (IFactory factory_) {
        vm.startBroadcast(_privateKey);
        factory_ = IFactory(FactoryDeployer.deploy());
        vm.stopBroadcast();
    }

    /* ============ Parameter Registry Helpers ============ */

    function _deploySettlementChainParameterRegistryImplementation() internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = SettlementChainParameterRegistryDeployer.deployImplementation(address(_factory));
        vm.stopBroadcast();
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
        address token_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = PayerRegistryDeployer.deployImplementation(address(_factory), parameterRegistry_, token_);
        vm.stopBroadcast();

        if (IPayerRegistry(implementation_).parameterRegistry() != parameterRegistry_) {
            revert("Payer registry parameter registry mismatch");
        }

        if (IPayerRegistry(implementation_).token() != token_) revert("Payer registry token mismatch");
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
        bytes[] memory keys_ = new bytes[](2);
        keys_[0] = _NODE_REGISTRY_ADMIN_KEY;
        keys_[1] = _NODE_REGISTRY_MAX_CANONICAL_NODES_KEY;

        bytes32[] memory values_ = new bytes32[](2);
        values_[0] = bytes32(uint256(uint160(_admin)));
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

        if (_nodeRegistryProxy.admin() != _admin) revert("Node registry admin not updated correctly");
        if (_nodeRegistryProxy.maxCanonicalNodes() != _NODE_REGISTRY_STARTING_MAX_CANONICAL_NODES) revert("Node registry max canonical not updated correctly");
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
        address token_
    ) internal returns (address implementation_) {
        vm.startBroadcast(_privateKey);
        (implementation_, ) = DistributionManagerDeployer.deployImplementation(
            address(_factory),
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            token_
        );
        vm.stopBroadcast();

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

        if (IDistributionManager(implementation_).token() != token_) revert("Distribution manager token mismatch");
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
}
