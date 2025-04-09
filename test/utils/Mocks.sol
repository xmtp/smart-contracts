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
    function set(bytes[] calldata keyChain_, bytes32 values) external {}

    function get(bytes[][] calldata keyChains_) external returns (bytes32[] memory values_) {}

    function get(bytes[] calldata keyChain_) external returns (bytes32 value_) {}
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
