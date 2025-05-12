// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockErc20 {
    function approve(address, uint256) external returns (bool success_) {
        return true;
    }

    function transfer(address, uint256) external returns (bool success_) {
        return true;
    }

    function transferFrom(address, address, uint256) external returns (bool success_) {
        return true;
    }

    function balanceOf(address) external view returns (uint256 balance_) {
        return 0;
    }
}

contract MockParameterRegistry {
    function set(bytes calldata key_, bytes32 values) external {}

    function get(bytes[] calldata keys_) external returns (bytes32[] memory values_) {}

    function get(bytes calldata key_) external returns (bytes32 value_) {}
}

contract MockMigrator {
    uint256 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address internal immutable _implementation;

    constructor(address implementation_) {
        _implementation = implementation_;
    }

    fallback() external payable {
        address implementation_ = _implementation;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }
}

contract MockFailingMigrator {
    error Failed();

    fallback() external payable {
        revert Failed();
    }
}

contract MockERC20Inbox {
    function depositERC20(uint256 amount_) external returns (uint256 messageNumber_) {}

    function sendContractTransaction(
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        address to_,
        uint256 value_,
        bytes calldata data_
    ) external returns (uint256 messageNumber_) {}

    function createRetryableTicket(
        address to_,
        uint256 l2CallValue_,
        uint256 maxSubmissionCost_,
        address excessFeeRefundAddress_,
        address callValueRefundAddress_,
        uint256 gasLimit_,
        uint256 maxFeePerGas_,
        uint256 tokenTotalFeeAmount_,
        bytes calldata data_
    ) external returns (uint256 messageNumber_) {}
}

contract MockNodeRegistry {
    uint8 public canonicalNodesCount;
    mapping(uint256 tokenId => address owner) public ownerOf;

    function getIsCanonicalNode(uint32 nodeId_) external view returns (bool isCanonicalNode_) {
        return true;
    }

    function getSigner(uint32 nodeId_) external view returns (address signer_) {}
}

contract MockPayerRegistry {
    struct PayerFee {
        address payer;
        uint96 fee;
    }

    function settleUsage(PayerFee[] calldata payerFees_) external returns (uint96 feesSettled_) {}
}

contract MockPayerReportManager {
    struct PayerReport {
        uint32 startSequenceId;
        uint32 endSequenceId;
        uint96 feesSettled;
        uint32 offset;
        bool isSettled;
        bytes32 payersMerkleRoot;
        uint32[] nodeIds;
    }

    function getPayerReports(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external view returns (PayerReport[] memory payerReports_) {}
}
