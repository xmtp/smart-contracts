// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { ParameterKeys } from "../../src/libraries/ParameterKeys.sol";
import { SequentialMerkleProofs } from "../../src/libraries/SequentialMerkleProofs.sol";

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
    constructor(address parameterRegistry_) NodeRegistry(parameterRegistry_) {}

    function __setMaxCanonicalNodes(uint256 maxCanonicalNodes_) external {
        _getNodeRegistryStorage().maxCanonicalNodes = uint8(maxCanonicalNodes_);
    }

    function __setCanonicalNodesCount(uint256 canonicalNodesCount_) external {
        _getNodeRegistryStorage().canonicalNodesCount = uint8(canonicalNodesCount_);
    }

    function __setNodeCount(uint256 nodeCount_) external {
        _getNodeRegistryStorage().nodeCount = uint32(nodeCount_);
    }

    function __setAdmin(address admin_) external {
        _getNodeRegistryStorage().admin = admin_;
    }

    function __setNodeManager(address nodeManager_) external {
        _getNodeRegistryStorage().nodeManager = nodeManager_;
    }

    function __setNodeOperatorCommissionPercent(uint256 nodeOperatorCommissionPercent_) external {
        _getNodeRegistryStorage().nodeOperatorCommissionPercent = uint16(nodeOperatorCommissionPercent_);
    }

    function __addNodeToCanonicalNetwork(uint256 nodeId_) external {
        _getNodeRegistryStorage().nodes[nodeId_].isCanonical = true;
    }

    function __removeNodeFromCanonicalNetwork(uint256 nodeId_) external {
        delete _getNodeRegistryStorage().nodes[nodeId_].isCanonical;
    }

    function __setNode(
        uint256 nodeId_,
        bytes calldata signingKeyPub_,
        string calldata httpAddress_,
        bool inCanonical_,
        uint256 minMonthlyFee_
    ) external {
        _getNodeRegistryStorage().nodes[nodeId_] = Node(signingKeyPub_, httpAddress_, inCanonical_, minMonthlyFee_);
    }

    function __setApproval(address to_, uint256 tokenId_, address authorizer_) external {
        _approve(to_, tokenId_, authorizer_);
    }

    function __mint(address to_, uint256 nodeId_) external {
        _mint(to_, nodeId_);
    }

    function __getNode(uint256 nodeId_) external view returns (Node memory node_) {
        return _getNodeRegistryStorage().nodes[nodeId_];
    }

    function __getOwner(uint256 nodeId_) external view returns (address owner_) {
        return _ownerOf(nodeId_);
    }

    function __getBaseURI() external view returns (string memory baseURI_) {
        return _baseURI();
    }

    function __getNodeCount() external view returns (uint32 nodeCount_) {
        return _getNodeRegistryStorage().nodeCount;
    }

    function __getIsCanonicalNode(uint256 nodeId_) external view returns (bool isCanonicalNode_) {
        return _getNodeRegistryStorage().nodes[nodeId_].isCanonical;
    }
}

contract RateRegistryHarness is RateRegistry {
    constructor(address parameterRegistry_) RateRegistry(parameterRegistry_) {}

    function __pushRates(
        uint256 messageFee,
        uint256 storageFee,
        uint256 congestionFee,
        uint256 targetRatePerMinute,
        uint256 startTime
    ) external {
        _getRateRegistryStorage().allRates.push(
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
        return _getRateRegistryStorage().allRates;
    }
}

contract PayerRegistryHarness is PayerRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address registry_, address token_) PayerRegistry(registry_, token_) {}

    function __setSettler(address settler_) external {
        _getPayerRegistryStorage().settler = settler_;
    }

    function __setFeeDistributor(address feeDistributor_) external {
        _getPayerRegistryStorage().feeDistributor = feeDistributor_;
    }

    function __setPauseStatus(bool paused_) external {
        _getPayerRegistryStorage().paused = paused_;
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

    function __getRegistryParameter(bytes calldata key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }

    function __setRegistryParameter(bytes calldata key_, address value_) external {
        __setRegistryParameter(key_, bytes32(uint256(uint160(value_))));
    }

    function __setRegistryParameter(bytes calldata key_, bool value_) external {
        __setRegistryParameter(key_, value_ ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function __setRegistryParameter(bytes calldata key_, uint256 value_) external {
        __setRegistryParameter(key_, bytes32(value_));
    }

    function __setRegistryParameter(bytes calldata key_, bytes32 value_) public {
        _getParameterRegistryStorage().parameters[key_] = value_;
    }
}

contract SettlementChainParameterRegistryHarness is SettlementChainParameterRegistry {
    function __getRegistryParameter(bytes calldata key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }
}

contract AppChainParameterRegistryHarness is AppChainParameterRegistry {
    function __getRegistryParameter(bytes calldata key_) external view returns (bytes32 value_) {
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

    function __setKeyNonce(bytes calldata key_, uint256 nonce_) external {
        _getAppChainGatewayStorage().keyNonces[key_] = nonce_;
    }

    function __getKeyNonce(bytes calldata key_) external view returns (uint256 nonce_) {
        return _getAppChainGatewayStorage().keyNonces[key_];
    }
}

contract ParameterKeysHarness {
    function getKey(bytes[] calldata keyComponents_) external pure returns (bytes memory key_) {
        return ParameterKeys.getKey(keyComponents_);
    }

    function combineKeyComponents(
        bytes calldata left_,
        bytes calldata right_
    ) external pure returns (bytes memory key_) {
        return ParameterKeys.combineKeyComponents(left_, right_);
    }

    function addressToKeyComponent(address account_) external pure returns (bytes memory keyComponent_) {
        return ParameterKeys.addressToKeyComponent(account_);
    }

    function uint256ToKeyComponent(uint256 value_) external pure returns (bytes memory keyComponent_) {
        return ParameterKeys.uint256ToKeyComponent(value_);
    }
}

contract SequentialMerkleProofsHarness {
    function verify(
        bytes32 root_,
        uint256 startingIndex_,
        bytes[] calldata leaves_,
        bytes32[] calldata proofElements_
    ) external pure {
        SequentialMerkleProofs.verify(root_, startingIndex_, leaves_, proofElements_);
    }

    function getRoot(
        uint256 startingIndex_,
        bytes[] calldata leaves_,
        bytes32[] calldata proofElements_
    ) external pure returns (bytes32 root_) {
        return SequentialMerkleProofs.getRoot(startingIndex_, leaves_, proofElements_);
    }

    function __bitCount32(uint256 n_) external pure returns (uint256 bitCount_) {
        return SequentialMerkleProofs._bitCount32(n_);
    }

    function __roundUpToPowerOf2(uint256 n_) external pure returns (uint256 powerOf2_) {
        return SequentialMerkleProofs._roundUpToPowerOf2(n_);
    }

    function __getBalancedLeafCount(uint256 leafCount_) external pure returns (uint256 balancedLeafCount_) {
        return SequentialMerkleProofs._getBalancedLeafCount(leafCount_);
    }

    function __hashLeaf(bytes calldata leaf_) external pure returns (bytes32 hash_) {
        return SequentialMerkleProofs._hashLeaf(leaf_);
    }

    function __hashNodePair(bytes32 leftNode_, bytes32 rightNode_) external pure returns (bytes32 hash_) {
        return SequentialMerkleProofs._hashNodePair(leftNode_, rightNode_);
    }

    function __hashPairlessNode(bytes32 node_) external pure returns (bytes32 hash_) {
        return SequentialMerkleProofs._hashPairlessNode(node_);
    }

    function __hashRoot(uint256 leafCount_, bytes32 root_) external pure returns (bytes32 hash_) {
        return SequentialMerkleProofs._hashRoot(leafCount_, root_);
    }

    function __getReversedLeafNodesFromLeaves(
        bytes[] calldata leaves_
    ) external pure returns (bytes32[] memory reversedLeaves_) {
        return SequentialMerkleProofs._getReversedLeafNodesFromLeaves(leaves_);
    }
}
