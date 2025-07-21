// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
    ERC20PermitUpgradeable
} from "../../lib/oz-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { RegistryParameters } from "../../src/libraries/RegistryParameters.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";

import { Migratable } from "../../src/abstract/Migratable.sol";

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

        emit IERC1967.Upgraded(implementation_);
    }
}

contract MockUnderlyingFeeToken is Migratable, ERC20PermitUpgradeable {
    address public immutable parameterRegistry;

    constructor(address parameterRegistry_) {
        parameterRegistry = parameterRegistry_;
    }

    function initialize() external initializer {
        __ERC20Permit_init("Mock USD");
        __ERC20_init("Mock USD", "mUSD");
    }

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }

    function migrate() external {
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    function decimals() public view virtual override returns (uint8 decimals_) {
        return 6;
    }

    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.mockUnderlyingFeeToken.migrator";
    }
}
