// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { AddressAliasHelper } from "../../src/libraries/AddressAliasHelper.sol";
import { ParameterKeys } from "../../src/libraries/ParameterKeys.sol";
import { RegistryParameters } from "../../src/libraries/RegistryParameters.sol";
import { SequentialMerkleProofs } from "../../src/libraries/SequentialMerkleProofs.sol";

import { AppChainGateway } from "../../src/app-chain/AppChainGateway.sol";
import { AppChainParameterRegistry } from "../../src/app-chain/AppChainParameterRegistry.sol";
import { DistributionManager } from "../../src/settlement-chain/DistributionManager.sol";
import { Factory } from "../../src/any-chain/Factory.sol";
import { FeeToken } from "../../src/settlement-chain/FeeToken.sol";
import { GroupMessageBroadcaster } from "../../src/app-chain/GroupMessageBroadcaster.sol";
import { IdentityUpdateBroadcaster } from "../../src/app-chain/IdentityUpdateBroadcaster.sol";
import { NodeRegistry } from "../../src/settlement-chain/NodeRegistry.sol";
import { ParameterRegistry } from "../../src/abstract/ParameterRegistry.sol";
import { PayerRegistry } from "../../src/settlement-chain/PayerRegistry.sol";
import { PayerReportManager } from "../../src/settlement-chain/PayerReportManager.sol";
import { PayloadBroadcaster } from "../../src/abstract/PayloadBroadcaster.sol";
import { RateRegistry } from "../../src/settlement-chain/RateRegistry.sol";
import { SettlementChainGateway } from "../../src/settlement-chain/SettlementChainGateway.sol";
import { SettlementChainParameterRegistry } from "../../src/settlement-chain/SettlementChainParameterRegistry.sol";

contract PayloadBroadcasterHarness is PayloadBroadcaster {
    constructor(address parameterRegistry_) PayloadBroadcaster(parameterRegistry_) {}

    function minPayloadSizeParameterKey() public pure override returns (string memory key_) {
        return "xmtp.payloadBroadcaster.minPayloadSize";
    }

    function maxPayloadSizeParameterKey() public pure override returns (string memory key_) {
        return "xmtp.payloadBroadcaster.maxPayloadSize";
    }

    function migratorParameterKey() public pure override returns (string memory key_) {
        return "xmtp.payloadBroadcaster.migrator";
    }

    function pausedParameterKey() public pure override returns (string memory key_) {
        return "xmtp.payloadBroadcaster.paused";
    }

    function payloadBootstrapperParameterKey() public pure override returns (string memory key_) {
        return "xmtp.payloadBroadcaster.payloadBootstrapper";
    }

    function __setPauseStatus(bool paused_) external {
        _getPayloadBroadcasterStorage().paused = paused_;
    }

    function __setSequenceId(uint64 sequenceId_) external {
        _getPayloadBroadcasterStorage().sequenceId = sequenceId_;
    }

    function __setMinPayloadSize(uint256 minPayloadSize_) external {
        _getPayloadBroadcasterStorage().minPayloadSize = uint32(minPayloadSize_);
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize_) external {
        _getPayloadBroadcasterStorage().maxPayloadSize = uint32(maxPayloadSize_);
    }

    function __setPayloadBootstrapper(address payloadBootstrapper_) external {
        _getPayloadBroadcasterStorage().payloadBootstrapper = payloadBootstrapper_;
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
        _getPayloadBroadcasterStorage().minPayloadSize = uint32(minPayloadSize_);
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize_) external {
        _getPayloadBroadcasterStorage().maxPayloadSize = uint32(maxPayloadSize_);
    }

    function __setPayloadBootstrapper(address payloadBootstrapper_) external {
        _getPayloadBroadcasterStorage().payloadBootstrapper = payloadBootstrapper_;
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
        _getPayloadBroadcasterStorage().minPayloadSize = uint32(minPayloadSize_);
    }

    function __setMaxPayloadSize(uint256 maxPayloadSize_) external {
        _getPayloadBroadcasterStorage().maxPayloadSize = uint32(maxPayloadSize_);
    }

    function __setPayloadBootstrapper(address payloadBootstrapper_) external {
        _getPayloadBroadcasterStorage().payloadBootstrapper = payloadBootstrapper_;
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

    function __addNodeToCanonicalNetwork(uint256 nodeId_) external {
        _getNodeRegistryStorage().nodes[uint32(nodeId_)].isCanonical = true;
    }

    function __removeNodeFromCanonicalNetwork(uint256 nodeId_) external {
        delete _getNodeRegistryStorage().nodes[uint32(nodeId_)].isCanonical;
    }

    function __setNode(
        uint256 nodeId_,
        address signer_,
        bool isCanonical_,
        bytes calldata signingPublicKey_,
        string calldata httpAddress_
    ) external {
        _getNodeRegistryStorage().nodes[uint32(nodeId_)] = Node(signer_, isCanonical_, signingPublicKey_, httpAddress_);
    }

    function __setApproval(address to_, uint256 tokenId_, address authorizer_) external {
        _approve(to_, tokenId_, authorizer_);
    }

    function __mint(address to_, uint256 nodeId_) external {
        _mint(to_, nodeId_);
    }

    function __getNode(uint256 nodeId_) external view returns (Node memory node_) {
        return _getNodeRegistryStorage().nodes[uint32(nodeId_)];
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
        return _getNodeRegistryStorage().nodes[uint32(nodeId_)].isCanonical;
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

    function __finalizeWithdrawal() external {
        _finalizeWithdrawal();
    }

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

    function __getUnderlyingFeeToken() external view returns (address underlyingFeeToken_) {
        return _underlyingFeeToken;
    }
}

contract ParameterRegistryHarness is ParameterRegistry {
    function migratorParameterKey() public pure override returns (string memory key_) {
        return "xmtp.parameterRegistry.migrator";
    }

    function adminParameterKey() public pure override returns (string memory key_) {
        return "xmtp.parameterRegistry.isAdmin";
    }

    function __getRegistryParameter(string calldata key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }

    function __setRegistryParameter(string calldata key_, address value_) external {
        __setRegistryParameter(key_, bytes32(uint256(uint160(value_))));
    }

    function __setRegistryParameter(string calldata key_, bool value_) external {
        __setRegistryParameter(key_, value_ ? bytes32(uint256(1)) : bytes32(uint256(0)));
    }

    function __setRegistryParameter(string calldata key_, uint256 value_) external {
        __setRegistryParameter(key_, bytes32(value_));
    }

    function __setRegistryParameter(string calldata key_, bytes32 value_) public {
        _getParameterRegistryStorage().parameters[key_] = value_;
    }
}

contract SettlementChainParameterRegistryHarness is SettlementChainParameterRegistry {
    function __getRegistryParameter(string calldata key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }
}

contract AppChainParameterRegistryHarness is AppChainParameterRegistry {
    function __getRegistryParameter(string calldata key_) external view returns (bytes32 value_) {
        return _getRegistryParameter(key_);
    }
}

contract SettlementChainGatewayHarness is SettlementChainGateway {
    constructor(
        address parameterRegistry_,
        address appChainGateway_,
        address feeToken_
    ) SettlementChainGateway(parameterRegistry_, appChainGateway_, feeToken_) {}

    function __setPauseStatus(bool paused_) external {
        _getSettlementChainGatewayStorage().paused = paused_;
    }

    function __setInbox(uint256 chainId_, address inbox_) external {
        _getSettlementChainGatewayStorage().inboxes[chainId_] = inbox_;
    }

    function __setNonce(uint256 nonce_) external {
        _getSettlementChainGatewayStorage().nonce = nonce_;
    }

    function __getInbox(uint256 chainId_) external view returns (address inbox_) {
        return _getSettlementChainGatewayStorage().inboxes[chainId_];
    }

    function __getNonce() external view returns (uint256 nonce_) {
        return _getSettlementChainGatewayStorage().nonce;
    }

    function __getUnderlyingFeeToken() external view returns (address underlyingFeeToken_) {
        return _underlyingFeeToken;
    }
}

contract AppChainGatewayHarness is AppChainGateway {
    constructor(
        address parameterRegistry_,
        address settlementChainGateway_
    ) AppChainGateway(parameterRegistry_, settlementChainGateway_) {}

    function __setPauseStatus(bool paused_) external {
        _getAppChainGatewayStorage().paused = paused_;
    }

    function __setKeyNonce(string calldata key_, uint256 nonce_) external {
        _getAppChainGatewayStorage().keyNonces[key_] = nonce_;
    }

    function __getKeyNonce(string calldata key_) external view returns (uint256 nonce_) {
        return _getAppChainGatewayStorage().keyNonces[key_];
    }
}

contract ParameterKeysHarness {
    function getKey(string[] calldata keyComponents_) external pure returns (string memory key_) {
        return ParameterKeys.getKey(keyComponents_);
    }

    function combineKeyComponents(
        string calldata left_,
        string calldata right_
    ) external pure returns (string memory key_) {
        return ParameterKeys.combineKeyComponents(left_, right_);
    }

    function addressToKeyComponent(address account_) external pure returns (string memory keyComponent_) {
        return ParameterKeys.addressToKeyComponent(account_);
    }

    function uint256ToKeyComponent(uint256 value_) external pure returns (string memory keyComponent_) {
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

    function getLeafCount(bytes32[] calldata proofElements_) external pure returns (uint256 leafCount_) {
        return SequentialMerkleProofs.getLeafCount(proofElements_);
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

contract PayerReportManagerHarness is PayerReportManager {
    constructor(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerRegistry_
    ) PayerReportManager(parameterRegistry_, nodeRegistry_, payerRegistry_) {}

    function __pushPayerReport(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint96 feesSettled_,
        uint32 offset_,
        bool isSettled_,
        uint16 protocolFeeRate_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_
    ) external {
        _getPayerReportManagerStorage().payerReportsByOriginator[originatorNodeId_].push(
            PayerReport({
                startSequenceId: startSequenceId_,
                endSequenceId: endSequenceId_,
                feesSettled: feesSettled_,
                offset: offset_,
                isSettled: isSettled_,
                protocolFeeRate: protocolFeeRate_,
                payersMerkleRoot: payersMerkleRoot_,
                nodeIds: nodeIds_
            })
        );
    }

    function __setProtocolFeeRate(uint16 protocolFeeRate_) external {
        _getPayerReportManagerStorage().protocolFeeRate = protocolFeeRate_;
    }

    function __verifySignatures(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_,
        PayerReportSignature[] calldata signatures_
    ) external view returns (uint32[] memory validSigningNodeIds_) {
        return
            _verifySignatures(
                originatorNodeId_,
                startSequenceId_,
                endSequenceId_,
                endMinuteSinceEpoch_,
                payersMerkleRoot_,
                nodeIds_,
                signatures_
            );
    }

    function __verifySignature(
        bytes32 digest_,
        uint32 nodeId_,
        bytes calldata signature_
    ) external view returns (bool isValid_) {
        return _verifySignature(digest_, nodeId_, signature_);
    }
}

contract DistributionManagerHarness is DistributionManager {
    constructor(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address token_
    ) DistributionManager(parameterRegistry_, nodeRegistry_, payerReportManager_, payerRegistry_, token_) {}

    function __prepareProtocolFeesWithdrawal(address protocolFeesRecipient_) external returns (uint96 withdrawn_) {
        return _prepareProtocolFeesWithdrawal(protocolFeesRecipient_);
    }

    function __prepareWithdrawal(uint256 nodeId_, address recipient_) external returns (uint96 withdrawn_) {
        return _prepareWithdrawal(uint32(nodeId_), recipient_);
    }

    function __setPauseStatus(bool paused_) external {
        _getDistributionManagerStorage().paused = paused_;
    }

    function __setProtocolFeesRecipient(address protocolFeesRecipient_) external {
        _getDistributionManagerStorage().protocolFeesRecipient = protocolFeesRecipient_;
    }

    function __setOwedProtocolFees(uint256 owedProtocolFees_) external {
        _getDistributionManagerStorage().owedProtocolFees = uint96(owedProtocolFees_);
    }

    function __setOwedFees(uint256 nodeId_, uint256 owedFees_) external {
        _getDistributionManagerStorage().owedFees[uint32(nodeId_)] = uint96(owedFees_);
    }

    function __setTotalOwedFees(uint256 totalOwedFees_) external {
        _getDistributionManagerStorage().totalOwedFees = uint96(totalOwedFees_);
    }

    function __setAreProtocolFeesClaimed(
        uint256 originatorNodeId_,
        uint256 payerReportIndex_,
        bool areClaimed_
    ) external {
        _getDistributionManagerStorage().areProtocolFeesClaimed[uint32(originatorNodeId_)][
            payerReportIndex_
        ] = areClaimed_;
    }

    function __setAreFeesClaimed(
        uint256 nodeId_,
        uint256 originatorNodeId_,
        uint256 payerReportIndex_,
        bool areClaimed_
    ) external {
        _getDistributionManagerStorage().areFeesClaimed[uint32(nodeId_)][uint32(originatorNodeId_)][
            payerReportIndex_
        ] = areClaimed_;
    }
}

contract FeeTokenHarness is FeeToken {
    constructor(address parameterRegistry_, address underlying_) FeeToken(parameterRegistry_, underlying_) {}

    function __mint(address recipient_, uint256 amount_) external {
        _mint(recipient_, amount_);
    }

    function __setPlaceholder(uint256 placeholder_) external {
        _getFeeTokenStorage().__placeholder = placeholder_;
    }

    function __getPlaceholder() external view returns (uint256 placeholder_) {
        return _getFeeTokenStorage().__placeholder;
    }
}

contract RegistryParametersHarness {
    function setRegistryParameter(address parameterRegistry_, string calldata key_, bytes32 value_) external {
        RegistryParameters.setRegistryParameter(parameterRegistry_, key_, value_);
    }

    function getRegistryParameters(
        address parameterRegistry_,
        string[] calldata keys_
    ) external view returns (bytes32[] memory values_) {
        return RegistryParameters.getRegistryParameters(parameterRegistry_, keys_);
    }

    function getRegistryParameter(
        address parameterRegistry_,
        string calldata key_
    ) external view returns (bytes32 value_) {
        return RegistryParameters.getRegistryParameter(parameterRegistry_, key_);
    }

    function getAddressParameter(
        address parameterRegistry_,
        string calldata key_
    ) external view returns (address value_) {
        return RegistryParameters.getAddressParameter(parameterRegistry_, key_);
    }

    function getBoolParameter(address parameterRegistry_, string calldata key_) external view returns (bool value_) {
        return RegistryParameters.getBoolParameter(parameterRegistry_, key_);
    }

    function getUint8Parameter(address parameterRegistry_, string calldata key_) external view returns (uint8 value_) {
        return RegistryParameters.getUint8Parameter(parameterRegistry_, key_);
    }

    function getUint16Parameter(
        address parameterRegistry_,
        string calldata key_
    ) external view returns (uint16 value_) {
        return RegistryParameters.getUint16Parameter(parameterRegistry_, key_);
    }

    function getUint32Parameter(
        address parameterRegistry_,
        string calldata key_
    ) external view returns (uint32 value_) {
        return RegistryParameters.getUint32Parameter(parameterRegistry_, key_);
    }

    function getUint64Parameter(
        address parameterRegistry_,
        string calldata key_
    ) external view returns (uint64 value_) {
        return RegistryParameters.getUint64Parameter(parameterRegistry_, key_);
    }

    function getUint96Parameter(
        address parameterRegistry_,
        string calldata key_
    ) external view returns (uint96 value_) {
        return RegistryParameters.getUint96Parameter(parameterRegistry_, key_);
    }

    function getAddressFromRawParameter(bytes32 parameter_) external pure returns (address value_) {
        return RegistryParameters.getAddressFromRawParameter(parameter_);
    }
}

contract AddressAliasHelperHarness {
    function toAlias(address account_) external pure returns (address alias_) {
        return AddressAliasHelper.toAlias(account_);
    }

    function fromAlias(address alias_) external pure returns (address account_) {
        return AddressAliasHelper.fromAlias(alias_);
    }
}

contract FactoryHarness is Factory {
    constructor(address parameterRegistry_) Factory(parameterRegistry_) {}

    function __setPauseStatus(bool paused_) external {
        _getFactoryStorage().paused = paused_;
    }
}
