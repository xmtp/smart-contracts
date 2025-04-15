// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { ParameterKeys } from "../../src/libraries/ParameterKeys.sol";

import { AppChainGateway } from "../../src/app-chain/AppChainGateway.sol";
import { AppChainParameterRegistry } from "../../src/app-chain/AppChainParameterRegistry.sol";
import { GroupMessageBroadcaster } from "../../src/app-chain/GroupMessageBroadcaster.sol";
import { IdentityUpdateBroadcaster } from "../../src/app-chain/IdentityUpdateBroadcaster.sol";
import { NodeRegistry } from "../../src/settlement-chain/NodeRegistry.sol";
import { ParameterRegistry } from "../../src/abstract/ParameterRegistry.sol";
import { PayerRegistry } from "../../src/settlement-chain/PayerRegistry.sol";
import { PayloadBroadcaster } from "../../src/abstract/PayloadBroadcaster.sol";
import { RateRegistry } from "../../src/settlement-chain/RateRegistry.sol";
import { SettlementChainGateway } from "../../src/settlement-chain/SettlementChainGateway.sol";
import { SettlementChainParameterRegistry } from "../../src/settlement-chain/SettlementChainParameterRegistry.sol";

contract PayloadBroadcasterHarness is PayloadBroadcaster {
    constructor(address parameterRegistry_) PayloadBroadcaster(parameterRegistry_) {}

    function minPayloadSizeParameterKey() public pure override returns (bytes memory key_) {
        return "xmtp.payloadBroadcaster.minPayloadSize";
    }

    function maxPayloadSizeParameterKey() public pure override returns (bytes memory key_) {
        return "xmtp.payloadBroadcaster.maxPayloadSize";
    }

    function migratorParameterKey() public pure override returns (bytes memory key_) {
        return "xmtp.payloadBroadcaster.migrator";
    }

    function pausedParameterKey() public pure override returns (bytes memory key_) {
        return "xmtp.payloadBroadcaster.paused";
    }

    function __setPauseStatus(bool paused_) external {
        _getPayloadBroadcasterStorage().paused = paused_;
    }

    function __setSequenceId(uint64 sequenceId_) external {
        _getPayloadBroadcasterStorage().sequenceId = sequenceId_;
    }

    function __setMinPayloadSize(uint256 minPayloadSize_) external {
        _getPayloadBroadcasterStorage().minPayloadSize = minPayloadSize_;
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize_) external {
        _getPayloadBroadcasterStorage().maxPayloadSize = maxPayloadSize_;
    }

    function __getSequenceId() external view returns (uint64 sequenceId_) {
        return _getPayloadBroadcasterStorage().sequenceId;
    }
}

contract GroupMessageBroadcasterHarness is GroupMessageBroadcaster {
    constructor(address parameterRegistry_) GroupMessageBroadcaster(parameterRegistry_) {}

    function __setPauseStatus(bool paused_) external {
        _getPayloadBroadcasterStorage().paused = paused_;
    }

    function __setSequenceId(uint64 sequenceId_) external {
        _getPayloadBroadcasterStorage().sequenceId = sequenceId_;
    }

    function __setMinPayloadSize(uint256 minPayloadSize_) external {
        _getPayloadBroadcasterStorage().minPayloadSize = minPayloadSize_;
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize_) external {
        _getPayloadBroadcasterStorage().maxPayloadSize = maxPayloadSize_;
    }

    function __getSequenceId() external view returns (uint64 sequenceId_) {
        return _getPayloadBroadcasterStorage().sequenceId;
    }
}

contract IdentityUpdateBroadcasterHarness is IdentityUpdateBroadcaster {
    constructor(address parameterRegistry_) IdentityUpdateBroadcaster(parameterRegistry_) {}

    function __setPauseStatus(bool paused_) external {
        _getPayloadBroadcasterStorage().paused = paused_;
    }

    function __setSequenceId(uint64 sequenceId_) external {
        _getPayloadBroadcasterStorage().sequenceId = sequenceId_;
    }

    function __setMinPayloadSize(uint256 minPayloadSize_) external {
        _getPayloadBroadcasterStorage().minPayloadSize = minPayloadSize_;
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize_) external {
        _getPayloadBroadcasterStorage().maxPayloadSize = maxPayloadSize_;
    }

    function __getSequenceId() external view returns (uint64 sequenceId_) {
        return _getPayloadBroadcasterStorage().sequenceId;
    }
}

contract NodeRegistryHarness is NodeRegistry {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(address initialAdmin) NodeRegistry(initialAdmin) {}

    function __setNodeCounter(uint256 nodeCounter) external {
        _nodeCounter = uint32(nodeCounter);
    }

    function __addNodeToCanonicalNetwork(uint256 nodeId) external {
        _canonicalNetworkNodes.add(nodeId);
    }

    function __removeNodeFromCanonicalNetwork(uint256 nodeId) external {
        _canonicalNetworkNodes.remove(nodeId);
    }

    function __setMaxActiveNodes(uint8 maxActiveNodes_) external {
        maxActiveNodes = maxActiveNodes_;
    }

    function __setNode(
        uint256 nodeId,
        bytes calldata signingKeyPub,
        string calldata httpAddress,
        bool inCanonicalNetwork,
        uint256 minMonthlyFeeMicroDollars
    ) external {
        _nodes[nodeId] = Node(signingKeyPub, httpAddress, inCanonicalNetwork, minMonthlyFeeMicroDollars);
    }

    function __setApproval(address to, uint256 tokenId, address authorizer) external {
        _approve(to, tokenId, authorizer);
    }

    function __mint(address to, uint256 nodeId) external {
        _mint(to, nodeId);
    }

    function __getNode(uint256 nodeId) external view returns (Node memory node) {
        return _nodes[nodeId];
    }

    function __getOwner(uint256 nodeId) external view returns (address owner) {
        return _ownerOf(nodeId);
    }

    function __getNodeCounter() external view returns (uint32 nodeCounter) {
        return _nodeCounter;
    }

    function __getBaseTokenURI() external view returns (string memory baseTokenURI) {
        return _baseTokenURI;
    }
}

contract RateRegistryHarness is RateRegistry {
    function __pause() external {
        _pause();
    }

    function __unpause() external {
        _unpause();
    }

    function __pushRates(
        uint256 messageFee,
        uint256 storageFee,
        uint256 congestionFee,
        uint256 targetRatePerMinute,
        uint256 startTime
    ) external {
        _getRatesManagerStorage().allRates.push(
            Rates(
                uint64(messageFee),
                uint64(storageFee),
                uint64(congestionFee),
                uint64(targetRatePerMinute),
                uint64(startTime)
            )
        );
    }

    function __getAllRates() external view returns (Rates[] memory rates_) {
        return _getRatesManagerStorage().allRates;
    }
}

contract PayerRegistryHarness is PayerRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address token_) PayerRegistry(token_) {}

    function __pause() external {
        _pause();
    }

    function __unpause() external {
        _unpause();
    }

    function __setMinimumDeposit(uint256 newMinimumDeposit_) external {
        _getPayerRegistryStorage().minimumDeposit = uint96(newMinimumDeposit_);
    }

    function __setWithdrawLockPeriod(uint256 newWithdrawLockPeriod_) external {
        _getPayerRegistryStorage().withdrawLockPeriod = uint32(newWithdrawLockPeriod_);
    }

    function __setBalance(address payer_, int256 balance_) external {
        _getPayerRegistryStorage().payers[payer_].balance = int104(balance_);
    }

    function __setPendingWithdrawal(address payer_, uint256 pendingWithdrawal_) external {
        _getPayerRegistryStorage().payers[payer_].pendingWithdrawal = uint96(pendingWithdrawal_);
    }

    function __setPendingWithdrawableTimestamp(address payer_, uint256 pendingWithdrawableTimestamp_) external {
        _getPayerRegistryStorage().payers[payer_].withdrawableTimestamp = uint32(pendingWithdrawableTimestamp_);
    }

    function __setWithdrawableTimestamp(address payer_, uint256 withdrawableTimestamp_) external {
        _getPayerRegistryStorage().payers[payer_].withdrawableTimestamp = uint32(withdrawableTimestamp_);
    }

    function __setTotalDeposits(int256 totalDeposits_) external {
        _getPayerRegistryStorage().totalDeposits = int104(totalDeposits_);
    }

    function __setTotalDebt(uint256 totalDebt_) external {
        _getPayerRegistryStorage().totalDebt = uint96(totalDebt_);
    }

    function __getPendingWithdrawal(address payer_) external view returns (uint96 pendingWithdrawal_) {
        return _getPayerRegistryStorage().payers[payer_].pendingWithdrawal;
    }

    function __getPendingWithdrawableTimestamp(address payer_) external view returns (uint32 withdrawableTimestamp_) {
        return _getPayerRegistryStorage().payers[payer_].withdrawableTimestamp;
    }
}

contract ParameterRegistryHarness is ParameterRegistry {
    function migratorParameterKey() public pure override returns (bytes memory key_) {
        return "xmtp.parameterRegistry.migrator";
    }

    function adminParameterKey() public pure override returns (bytes memory key_) {
        return "xmtp.parameterRegistry.isAdmin";
    }

    function __getRegistryParameter(bytes memory key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }

    function __setRegistryParameter(bytes memory key_, address value_) external {
        __setRegistryParameter(key_, bytes32(uint256(uint160(value_))));
    }

    function __setRegistryParameter(bytes memory key_, bool value_) external {
        __setRegistryParameter(key_, value_ ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function __setRegistryParameter(bytes memory key_, uint256 value_) external {
        __setRegistryParameter(key_, bytes32(value_));
    }

    function __setRegistryParameter(bytes memory key_, bytes32 value_) public {
        _getParameterRegistryStorage().parameters[key_] = value_;
    }
}

contract SettlementChainParameterRegistryHarness is SettlementChainParameterRegistry {
    function __getRegistryParameter(bytes memory key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }
}

contract AppChainParameterRegistryHarness is AppChainParameterRegistry {
    function __getRegistryParameter(bytes memory key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }
}

contract SettlementChainGatewayHarness is SettlementChainGateway {
    constructor(
        address parameterRegistry_,
        address appChainGateway_,
        address appChainNativeToken_
    ) SettlementChainGateway(parameterRegistry_, appChainGateway_, appChainNativeToken_) {}

    function __setNonce(uint256 nonce_) external {
        _getSettlementChainGatewayStorage().nonce = nonce_;
    }

    function __getNonce() external view returns (uint256 nonce_) {
        return _getSettlementChainGatewayStorage().nonce;
    }
}

contract AppChainGatewayHarness is AppChainGateway {
    constructor(
        address parameterRegistry_,
        address settlementChainGateway_
    ) AppChainGateway(parameterRegistry_, settlementChainGateway_) {}

    function __setKeyNonce(bytes memory key_, uint256 nonce_) external {
        _getAppChainGatewayStorage().keyNonces[key_] = nonce_;
    }

    function __getKeyNonce(bytes memory key_) external view returns (uint256 nonce_) {
        return _getAppChainGatewayStorage().keyNonces[key_];
    }
}

contract ParameterKeysHarness {
    function getKey(bytes[] memory keyComponents_) external pure returns (bytes memory key_) {
        return ParameterKeys.getKey(keyComponents_);
    }

    function combineKeyComponents(bytes memory left_, bytes memory right_) external pure returns (bytes memory key_) {
        return ParameterKeys.combineKeyComponents(left_, right_);
    }

    function addressToKeyComponent(address account_) external pure returns (bytes memory keyComponent_) {
        return ParameterKeys.addressToKeyComponent(account_);
    }

    function uint256ToKeyComponent(uint256 value_) external pure returns (bytes memory keyComponent_) {
        return ParameterKeys.uint256ToKeyComponent(value_);
    }
}
