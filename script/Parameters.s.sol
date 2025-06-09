// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { IGroupMessageBroadcaster } from "../src/app-chain/interfaces/IGroupMessageBroadcaster.sol";
import { IIdentityUpdateBroadcaster } from "../src/app-chain/interfaces/IIdentityUpdateBroadcaster.sol";
import { INodeRegistry } from "../src/settlement-chain/interfaces/INodeRegistry.sol";
import { IPayerRegistry } from "../src/settlement-chain/interfaces/IPayerRegistry.sol";
import { IRateRegistry } from "../src/settlement-chain/interfaces/IRateRegistry.sol";
import { ISettlementChainGateway } from "../src/settlement-chain/interfaces/ISettlementChainGateway.sol";

import {
    ISettlementChainParameterRegistry
} from "../src/settlement-chain/interfaces/ISettlementChainParameterRegistry.sol";

import { IERC20Like } from "./Interfaces.sol";

import { Utils } from "./utils/Utils.sol";

contract ParameterScripts is Script {
    error DeployerNotSet();
    error EnvironmentNotSet();
    error GatewayProxyNotSet();
    error GroupMessageBroadcasterProxyNotSet();
    error IdentityUpdateBroadcasterProxyNotSet();
    error InsufficientBalance();
    error NodeRegistryProxyNotSet();
    error ParameterRegistryProxyNotSet();
    error PayerRegistryProxyNotSet();
    error PrivateKeyNotSet();
    error RateRegistryProxyNotSet();
    error UnexpectedAdmin();
    error UnexpectedChainId();

    bytes internal constant _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.minPayloadSize";

    bytes internal constant _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
        "xmtp.groupMessageBroadcaster.maxPayloadSize";

    bytes internal constant _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY =
        "xmtp.identityUpdateBroadcaster.minPayloadSize";

    bytes internal constant _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY =
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

        if (admin_ == address(0)) revert DeployerNotSet();

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

        (bytes[] memory keys_, bytes32[] memory values_) = Utils.parseStartingParameters(
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
    }

    function bridgeBroadcasterPayloadSizeParameters() external {
        if (_deploymentData.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        bytes[] memory keys_ = new bytes[](4);
        keys_[0] = _GROUP_MESSAGE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[1] = _GROUP_MESSAGE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;
        keys_[2] = _IDENTITY_UPDATE_BROADCASTER_MIN_PAYLOAD_SIZE_KEY;
        keys_[3] = _IDENTITY_UPDATE_BROADCASTER_MAX_PAYLOAD_SIZE_KEY;

        address[] memory inboxes_ = new address[](1);
        inboxes_[0] = _deploymentData.settlementChainInboxToAppchain;

        vm.startBroadcast(_privateKey);

        // TODO: Either compute/estimate the values or use a more flexible approach via the config file.

        if (IERC20Like(_deploymentData.appChainNativeToken).balanceOf(_admin) < 1_000000) {
            revert InsufficientBalance();
        }

        IERC20Like(_deploymentData.appChainNativeToken).approve(_deploymentData.gatewayProxy, 1_000000); // 1 USDC

        ISettlementChainGateway(_deploymentData.gatewayProxy).sendParametersAsRetryableTickets(
            inboxes_,
            keys_,
            400_000,
            2_000_000_000, // 2 gwei
            1_000000, // 1 USDC
            1_000000 // 1 USDC
        );

        vm.stopBroadcast();
    }

    function updateAppChainStartingParameters() external {
        updateGroupMessageBroadcasterStartingParameters();
        updateIdentityUpdateBroadcasterStartingParameters();
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
}
