// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "../../lib/oz/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "../../lib/oz/contracts/token/ERC20/extensions/ERC20Permit.sol";

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

contract MockERC20 is ERC20Permit {
    uint8 internal immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Permit(name_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
