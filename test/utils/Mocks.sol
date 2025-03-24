// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockErc20 {
    function transfer(address, uint256) external pure returns (bool success_) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool success_) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256 balance_) {
        return 0;
    }
}

contract MockParameterRegistry {
    function get(bytes[] calldata keyChain_) external pure returns (bytes32 value_) {}
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
