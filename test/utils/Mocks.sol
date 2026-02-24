// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
    ERC20PermitUpgradeable
} from "../../lib/oz-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

import { EnumerableSet } from "../../lib/oz/contracts/utils/structs/EnumerableSet.sol";

import { RegistryParameters } from "../../src/libraries/RegistryParameters.sol";

import { IERC1967 } from "../../src/abstract/interfaces/IERC1967.sol";
import { INodeRegistry } from "../../src/settlement-chain/interfaces/INodeRegistry.sol";

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

contract MockNodeRegistryProxy {
    using EnumerableSet for EnumerableSet.UintSet;

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.NodeRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _NODE_REGISTRY_STORAGE_LOCATION =
        0xd48713bc7b5e2644bcb4e26ace7d67dc9027725a9a1ee11596536cc6096a2000;

    struct NodeRegistryStorage {
        address admin;
        uint8 maxCanonicalNodes;
        uint8 canonicalNodesCount;
        uint32 nodeCount;
        mapping(uint32 nodeId => INodeRegistry.Node node) nodes;
        string baseURI;
        EnumerableSet.UintSet canonicalNodes;
    }

    function _getStorage() internal pure returns (NodeRegistryStorage storage $) {
        assembly {
            $.slot := _NODE_REGISTRY_STORAGE_LOCATION
        }
    }

    function setImplementation(address implementation_) external {
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, implementation_)
        }
    }

    function callMigrator(address migrator_) external {
        (bool success_, bytes memory data_) = migrator_.delegatecall("");

        if (success_) return;

        assembly {
            revert(add(data_, 0x20), mload(data_))
        }
    }

    function setNodeCount(uint32 count_) external {
        _getStorage().nodeCount = count_;
    }

    function setNodeCanonical(uint32 nodeId_) external {
        _getStorage().nodes[nodeId_].isCanonical = true;
    }

    function setNodeNonCanonical(uint32 nodeId_) external {
        _getStorage().nodes[nodeId_].isCanonical = false;
    }

    function addToCanonicalSet(uint32 nodeId_) external {
        _getStorage().canonicalNodes.add(nodeId_);
    }

    function getCanonicalNodesCount() external view returns (uint256 count_) {
        return _getStorage().canonicalNodes.length();
    }

    function isInCanonicalSet(uint32 nodeId_) external view returns (bool isIn_) {
        return _getStorage().canonicalNodes.contains(nodeId_);
    }
}
