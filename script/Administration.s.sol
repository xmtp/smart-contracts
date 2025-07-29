// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { IFactory } from "../src/any-chain/interfaces/IFactory.sol";
import { IGroupMessageBroadcaster } from "../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { IMigratable } from "../src/abstract/interfaces/IMigratable.sol";
import { INodeRegistry } from "../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IParameterRegistry } from "../src/abstract/interfaces/IParameterRegistry.sol";
import { IPayerRegistry } from "../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IPayerReportManager } from "../src/settlement-chain/interfaces/IPayerReportManager.sol";
import { IRateRegistry } from "../src/settlement-chain/interfaces/IRateRegistry.sol";
import { ISettlementChainGateway } from "../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import {
    ISettlementChainParameterRegistry
} from "../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

import { Migrator } from "../src/any-chain/Migrator.sol";

import { IERC20Like } from "./Interfaces.sol";

import { Utils } from "./utils/Utils.sol";

contract AdministrationScripts is Script {
    error AdminNotSet();
    error DeployerNotSet();
    error EnvironmentNotSet();
    error GatewayProxyNotSet();
    error GroupMessageBroadcasterProxyNotSet();
    error IdentityUpdateBroadcasterProxyNotSet();
    error InsufficientBalance();
    error NodeRegistryProxyNotSet();
    error ParameterRegistryProxyNotSet();
    error PayerRegistryProxyNotSet();
    error PayerReportManagerProxyNotSet();
    error PrivateKeyNotSet();
    error RateRegistryProxyNotSet();
    error UnexpectedAdmin();
    error UnexpectedChainId();
    error UnexpectedMigration();
    error UnexpectedMigrator();
    error ZeroImplementation();

    uint256 internal constant _TX_STIPEND = 21_000;
    uint256 internal constant _GAS_PER_BRIDGED_KEY = 75_000;
    uint256 internal constant _APP_CHAIN_GAS_PRICE = 2_000_000_000; // 2 gwei per gas.

    string internal constant _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.minPayloadSize";

    string internal constant _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.maxPayloadSize";

    string internal constant _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.minPayloadSize";

    string internal constant _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.maxPayloadSize";

    Utils.DeploymentData internal _deploymentData;

    string internal _environment;

    uint256 internal _privateKey;
    address internal _admin;

    function setUp() external {
        _environment = vm.envString("ENVIRONMENT");

        if (bytes(_environment).length == 0) revert EnvironmentNotSet();

        console.log("Environment: %s", _environment);

        _deploymentData = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        if (_deploymentData.deployer == address(0)) revert DeployerNotSet();

        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));

        if (_privateKey == 0) revert PrivateKeyNotSet();

        address admin_ = vm.envAddress("ADMIN");

        if (admin_ == address(0)) revert AdminNotSet();

        _admin = vm.addr(_privateKey);

        console.log("Admin: %s", _admin);

        if (
            _admin != _deploymentData.settlementChainParameterRegistryAdmin1 &&
            _admin != _deploymentData.settlementChainParameterRegistryAdmin2 &&
            _admin != _deploymentData.settlementChainParameterRegistryAdmin3
        ) {
            revert UnexpectedAdmin();
        }

        if (_admin != admin_) revert UnexpectedAdmin();
    }

    /* ============ Main Entrypoints ============ */

    function setStartingParameters() external {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        (string[] memory keys_, bytes32[] memory values_) = Utils.parseStartingParameters(
            string.concat("config/", _environment, ".json")
        );

        console.log("Starting Parameter Count: %s", keys_.length);

        vm.startBroadcast(_privateKey);
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(keys_, values_);
        vm.stopBroadcast();
    }

    function updateSettlementChainStartingParameters() external {
        updateNodeRegistryStartingParameters();
        updatePayerRegistryStartingParameters();
        updateRateRegistryStartingParameters();
        updateSettlementChainGatewayStartingParameters();
        updatePayerReportManagerStartingParameters();
    }

    function bridgeStartingParameters() external {
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        string[] memory keys_ = new string[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * keys_.length);

        // Convert from 18 decimals (app chain gas token) to 6 decimals (fee token).
        uint256 cost_ = ((_APP_CHAIN_GAS_PRICE * gasLimit_) * 1e6) / 1e18;

        if (IERC20Like(_deploymentData.feeTokenProxy).balanceOf(_admin) < cost_) revert InsufficientBalance();

        vm.startBroadcast(_privateKey);

        IERC20Like(_deploymentData.feeTokenProxy).approve(_deploymentData.gatewayProxy, cost_);

        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = _deploymentData.appChainId;

        ISettlementChainGateway(_deploymentData.gatewayProxy).sendParameters(
            chainIds_,
            keys_,
            gasLimit_,
            _APP_CHAIN_GAS_PRICE,
            cost_
        );

        vm.stopBroadcast();
    }

    function updateAppChainStartingParameters() external {
        updateGroupMessageBroadcasterStartingParameters();
        updateIdentityUpdateBroadcasterStartingParameters();
    }

    function deploySettlementChainMigrators() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        _deployMigratorForProxy(
            _deploymentData.distributionManagerProxy,
            _deploymentData.distributionManagerImplementation
        );

        _deployMigratorForProxy(_deploymentData.factory, _deploymentData.factoryImplementation);
        _deployMigratorForProxy(_deploymentData.feeTokenProxy, _deploymentData.feeTokenImplementation);
        _deployMigratorForProxy(_deploymentData.gatewayProxy, _deploymentData.settlementChainGatewayImplementation);
        _deployMigratorForProxy(_deploymentData.nodeRegistryProxy, _deploymentData.nodeRegistryImplementation);
        _deployMigratorForProxy(_deploymentData.payerRegistryProxy, _deploymentData.payerRegistryImplementation);

        _deployMigratorForProxy(
            _deploymentData.parameterRegistryProxy,
            _deploymentData.settlementChainParameterRegistryImplementation
        );

        _deployMigratorForProxy(
            _deploymentData.payerReportManagerProxy,
            _deploymentData.payerReportManagerImplementation
        );

        _deployMigratorForProxy(_deploymentData.rateRegistryProxy, _deploymentData.rateRegistryImplementation);

        _deployMigratorForProxy(
            _deploymentData.underlyingFeeToken,
            _deploymentData.mockUnderlyingFeeTokenImplementation
        );
    }

    function deployAppChainMigrators() external {
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        _deployMigratorForProxy(_deploymentData.factory, _deploymentData.factoryImplementation);
        _deployMigratorForProxy(_deploymentData.gatewayProxy, _deploymentData.appChainGatewayImplementation);

        _deployMigratorForProxy(
            _deploymentData.groupMessageBroadcasterProxy,
            _deploymentData.groupMessageBroadcasterImplementation
        );

        _deployMigratorForProxy(
            _deploymentData.identityUpdateBroadcasterProxy,
            _deploymentData.identityUpdateBroadcasterImplementation
        );

        _deployMigratorForProxy(
            _deploymentData.parameterRegistryProxy,
            _deploymentData.appChainParameterRegistryImplementation
        );
    }

    function setMigratorParameters() external {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        (string[] memory keys_, bytes32[] memory values_) = Utils.parseMigratorParameters(
            string.concat("config/", _environment, ".json")
        );

        console.log("Migrator Parameter Count: %s", keys_.length);

        vm.startBroadcast(_privateKey);
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(keys_, values_);
        vm.stopBroadcast();
    }

    function unsetMigratorParameters() external {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        (string[] memory keys_, ) = Utils.parseMigratorParameters(string.concat("config/", _environment, ".json"));

        console.log("Migrator Parameter Count: %s", keys_.length);

        bytes32[] memory values_ = new bytes32[](keys_.length);

        vm.startBroadcast(_privateKey);
        ISettlementChainParameterRegistry(_deploymentData.parameterRegistryProxy).set(keys_, values_);
        vm.stopBroadcast();
    }

    function migrateSettlementChainProxies() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        _migrate(_deploymentData.distributionManagerProxy, _deploymentData.distributionManagerImplementation);
        _migrate(_deploymentData.factory, _deploymentData.factoryImplementation);
        _migrate(_deploymentData.feeTokenProxy, _deploymentData.feeTokenImplementation);
        _migrate(_deploymentData.gatewayProxy, _deploymentData.settlementChainGatewayImplementation);
        _migrate(_deploymentData.nodeRegistryProxy, _deploymentData.nodeRegistryImplementation);
        _migrate(_deploymentData.payerRegistryProxy, _deploymentData.payerRegistryImplementation);

        _migrate(
            _deploymentData.parameterRegistryProxy,
            _deploymentData.settlementChainParameterRegistryImplementation
        );

        _migrate(_deploymentData.payerReportManagerProxy, _deploymentData.payerReportManagerImplementation);
        _migrate(_deploymentData.rateRegistryProxy, _deploymentData.rateRegistryImplementation);
        _migrate(_deploymentData.underlyingFeeToken, _deploymentData.mockUnderlyingFeeTokenImplementation);
    }

    function bridgeMigratorParameters() external {
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        (string[] memory keys_, ) = Utils.parseMigratorParameters(string.concat("config/", _environment, ".json"));

        console.log("Migrator Parameter Count: %s", keys_.length);

        uint256 count_ = 0;

        for (uint256 index_; index_ < keys_.length; ++index_) {
            if (!_isAppChainMigratorParameterKey(keys_[index_])) continue;

            ++count_;
        }

        console.log("App Chain Migrator Parameter Count: %s", count_);

        string[] memory appChainKeys_ = new string[](count_);

        uint256 outputIndex_ = 0;

        for (uint256 index_; index_ < keys_.length; ++index_) {
            if (!_isAppChainMigratorParameterKey(keys_[index_])) continue;

            appChainKeys_[outputIndex_] = keys_[index_];

            ++outputIndex_;
        }

        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * appChainKeys_.length);

        // Convert from 18 decimals (app chain gas token) to 6 decimals (fee token).
        uint256 cost_ = ((_APP_CHAIN_GAS_PRICE * gasLimit_) * 1e6) / 1e18;

        if (IERC20Like(_deploymentData.feeTokenProxy).balanceOf(_admin) < cost_) revert InsufficientBalance();

        vm.startBroadcast(_privateKey);

        IERC20Like(_deploymentData.feeTokenProxy).approve(_deploymentData.gatewayProxy, cost_);

        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = _deploymentData.appChainId;

        ISettlementChainGateway(_deploymentData.gatewayProxy).sendParameters(
            chainIds_,
            appChainKeys_,
            gasLimit_,
            _APP_CHAIN_GAS_PRICE,
            cost_
        );

        vm.stopBroadcast();
    }

    function migrateAppChainProxies() external {
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        _migrate(_deploymentData.factory, _deploymentData.factoryImplementation);
        _migrate(_deploymentData.gatewayProxy, _deploymentData.appChainGatewayImplementation);
        _migrate(_deploymentData.groupMessageBroadcasterProxy, _deploymentData.groupMessageBroadcasterImplementation);

        _migrate(
            _deploymentData.identityUpdateBroadcasterProxy,
            _deploymentData.identityUpdateBroadcasterImplementation
        );

        _migrate(_deploymentData.parameterRegistryProxy, _deploymentData.appChainParameterRegistryImplementation);
    }

    /* ============ Individual Functions ============ */

    function updateNodeRegistryStartingParameters() public {
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        INodeRegistry(_deploymentData.nodeRegistryProxy).updateAdmin();
        INodeRegistry(_deploymentData.nodeRegistryProxy).updateMaxCanonicalNodes();
        vm.stopBroadcast();
    }

    function updatePayerRegistryStartingParameters() public {
        if (_deploymentData.payerRegistryProxy == address(0)) revert PayerRegistryProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateSettler();
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateFeeDistributor();
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateMinimumDeposit();
        IPayerRegistry(_deploymentData.payerRegistryProxy).updateWithdrawLockPeriod();
        vm.stopBroadcast();
    }

    function updateRateRegistryStartingParameters() public {
        if (_deploymentData.rateRegistryProxy == address(0)) revert RateRegistryProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        IRateRegistry(_deploymentData.rateRegistryProxy).updateRates();
        vm.stopBroadcast();
    }

    function updateSettlementChainGatewayStartingParameters() public {
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        ISettlementChainGateway(_deploymentData.gatewayProxy).updateInbox(_deploymentData.appChainId);
        vm.stopBroadcast();
    }

    function updatePayerReportManagerStartingParameters() public {
        if (_deploymentData.payerReportManagerProxy == address(0)) revert PayerReportManagerProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        IPayerReportManager(_deploymentData.payerReportManagerProxy).updateProtocolFeeRate();
        vm.stopBroadcast();
    }

    function updateGroupMessageBroadcasterStartingParameters() public {
        if (_deploymentData.groupMessageBroadcasterProxy == address(0)) revert GroupMessageBroadcasterProxyNotSet();
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        IGroupMessageBroadcaster(_deploymentData.groupMessageBroadcasterProxy).updateMaxPayloadSize();
        IGroupMessageBroadcaster(_deploymentData.groupMessageBroadcasterProxy).updateMinPayloadSize();
        vm.stopBroadcast();
    }

    function updateIdentityUpdateBroadcasterStartingParameters() public {
        if (_deploymentData.identityUpdateBroadcasterProxy == address(0)) revert IdentityUpdateBroadcasterProxyNotSet();
        if (block.chainid != _deploymentData.appChainId) revert UnexpectedChainId();

        vm.startBroadcast(_privateKey);
        IIdentityUpdateBroadcaster(_deploymentData.identityUpdateBroadcasterProxy).updateMaxPayloadSize();
        IIdentityUpdateBroadcaster(_deploymentData.identityUpdateBroadcasterProxy).updateMinPayloadSize();
        vm.stopBroadcast();
    }

    /* ============ Internal Functions ============ */

    function _deployMigratorForProxy(address proxy_, address toImplementation_) internal returns (address migrator_) {
        string memory key_ = _getMigratorParameterKey(proxy_);

        // If the proxy does not have a migrator parameter key, then it is not migratable this way (or at all).
        if (bytes(key_).length == 0) return address(0);

        address currentImplementation_ = IMigratable(proxy_).implementation();

        // If the current implementation is already the same as the to implementation, do nothing.
        if (currentImplementation_ == toImplementation_) return address(0);

        // If the to implementation does not have the same migrator parameter key, then it is incompatible.
        vm.assertEq(key_, _getMigratorParameterKey(toImplementation_), "IncompatibleImplementation");

        vm.startBroadcast(_privateKey);

        // Deploy a migrator to specifically migrate proxies from the current implementation to the new implementation.
        migrator_ = _deployMigrator(currentImplementation_, toImplementation_);

        vm.stopBroadcast();

        console.log("Migrator: %s %s", key_, migrator_);
    }

    function _deployMigrator(
        address fromImplementation_,
        address toImplementation_
    ) internal returns (address migrator_) {
        if (fromImplementation_ == address(0)) revert ZeroImplementation();
        if (toImplementation_ == address(0)) revert ZeroImplementation();

        bytes memory constructorArguments_ = abi.encode(fromImplementation_, toImplementation_);
        bytes memory creationCode_ = abi.encodePacked(type(Migrator).creationCode, constructorArguments_);

        migrator_ = IFactory(_deploymentData.factory).computeImplementationAddress(creationCode_);

        if (migrator_.code.length == 0) {
            migrator_ = IFactory(_deploymentData.factory).deployImplementation(creationCode_);
        }

        if (Migrator(migrator_).fromImplementation() != fromImplementation_) revert UnexpectedMigrator();
        if (Migrator(migrator_).toImplementation() != toImplementation_) revert UnexpectedMigrator();

        return migrator_;
    }

    function _getMigratorParameterKey(address proxy_) internal view returns (string memory key_) {
        (bool success_, bytes memory data_) = proxy_.staticcall(abi.encodeWithSignature("migratorParameterKey()"));

        if (!success_) return "";

        return abi.decode(data_, (string));
    }

    function _migrate(address proxy_, address toImplementation_) internal {
        string memory key_ = _getMigratorParameterKey(proxy_);

        // If the proxy does not have a migrator parameter key, then it is not migratable this way (or at all).
        if (bytes(key_).length == 0) return;

        address currentImplementation_ = IMigratable(proxy_).implementation();

        // If the current implementation is already the same as the to implementation, do nothing.
        if (currentImplementation_ == toImplementation_) return;

        vm.startBroadcast(_privateKey);

        IMigratable(proxy_).migrate();

        if (IMigratable(proxy_).implementation() != toImplementation_) revert UnexpectedMigration();

        vm.assertEq(_getMigratorParameterKey(proxy_), key_, "UnexpectedMigration");

        vm.stopBroadcast();
    }

    function _isAppChainMigratorParameterKey(string memory key_) internal pure returns (bool) {
        bytes32 keyHash_ = keccak256(bytes(key_));

        return
            keyHash_ == keccak256(bytes("xmtp.factory.migrator")) ||
            keyHash_ == keccak256(bytes("xmtp.appChainGateway.migrator")) ||
            keyHash_ == keccak256(bytes("xmtp.appChainParameterRegistry.migrator")) ||
            keyHash_ == keccak256(bytes("xmtp.groupMessageBroadcaster.migrator")) ||
            keyHash_ == keccak256(bytes("xmtp.identityUpdateBroadcaster.migrator"));
    }
}
