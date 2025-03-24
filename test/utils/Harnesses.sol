// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { GroupMessageBroadcaster } from "../../src/GroupMessageBroadcaster.sol";
import { IdentityUpdateBroadcaster } from "../../src/IdentityUpdateBroadcaster.sol";
import { NodeRegistry } from "../../src/NodeRegistry.sol";
import { RateRegistry } from "../../src/RateRegistry.sol";
import { PayerRegistry } from "../../src/PayerRegistry.sol";
import { ParameterRegistry } from "../../src/ParameterRegistry.sol";
contract GroupMessageBroadcasterHarness is GroupMessageBroadcaster {
    constructor(address registry_) GroupMessageBroadcaster(registry_) {}

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
    constructor(address registry_) IdentityUpdateBroadcaster(registry_) {}

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

    function __getAllRates() external view returns (Rates[] memory) {
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
