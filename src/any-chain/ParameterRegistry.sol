// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";

import { Migratable } from "../abstract/Migratable.sol";

import { IParameterRegistry } from "./interfaces/IParameterRegistry.sol";

contract ParameterRegistry is IParameterRegistry, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    bytes internal constant _DOT = bytes(".");

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.ParameterRegistry
    struct ParameterRegistryStorage {
        mapping(bytes key => bytes32 value) parameters;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.ParameterRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PARAMETER_REGISTRY_STORAGE_LOCATION =
        0xefab3f4eb315eafaa267b58974a509c07c739fbfe8e62b4eff49c4ced6985000;

    function _getParameterRegistryStorage() internal pure returns (ParameterRegistryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _PARAMETER_REGISTRY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Initialization ============ */

    function initialize(address[] calldata admins_) external initializer {
        ParameterRegistryStorage storage $ = _getParameterRegistryStorage();

        bytes[] memory keyChain_ = new bytes[](2);
        keyChain_[0] = adminParameterKey();

        for (uint256 index_; index_ < admins_.length; ++index_) {
            keyChain_[1] = abi.encode(admins_[index_]);

            _setParameter($, keyChain_, bytes32(uint256(1)));
        }
    }

    /* ============ Interactive Functions ============ */

    function set(bytes[][] calldata keyChains_, bytes32[] calldata values_) external onlyAdmin {
        require(keyChains_.length > 0, NoKeyChains());
        require(keyChains_.length == values_.length, ArrayLengthMismatch());

        ParameterRegistryStorage storage $ = _getParameterRegistryStorage();

        for (uint256 index_; index_ < keyChains_.length; ++index_) {
            _setParameter($, keyChains_[index_], values_[index_]);
        }
    }

    function set(bytes[] calldata keyChain_, bytes32 value_) external onlyAdmin {
        _setParameter(_getParameterRegistryStorage(), keyChain_, value_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(address(uint160(uint256(_getRegistryParameter(migratorParameterKey())))));
    }

    /* ============ View/Pure Functions ============ */

    function migratorParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.appchain.pr.migrator";
    }

    function adminParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.appchain.pr.isAdmin";
    }

    function isAdmin(address account_) public view returns (bool isAdmin_) {
        bytes memory key_ = _combineKeyChainParts(adminParameterKey(), abi.encode(account_));
        return _getRegistryParameter(key_) != bytes32(uint256(0));
    }

    function get(bytes[][] calldata keyChains_) external view returns (bytes32[] memory values_) {
        require(keyChains_.length > 0, NoKeyChains());

        values_ = new bytes32[](keyChains_.length);
        ParameterRegistryStorage storage $ = _getParameterRegistryStorage();

        for (uint256 index_; index_ < keyChains_.length; ++index_) {
            values_[index_] = $.parameters[_getKey(keyChains_[index_])];
        }
    }

    function get(bytes[] calldata keyChain_) external view returns (bytes32 value_) {
        return _getParameterRegistryStorage().parameters[_getKey(keyChain_)];
    }

    /* ============ Internal Interactive Functions ============ */

    function _setParameter(ParameterRegistryStorage storage $, bytes[] memory keyChain_, bytes32 value_) internal {
        bytes memory key_ = _getKey(keyChain_);
        emit ParameterSet(key_, keyChain_, $.parameters[key_] = value_);
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getKey(bytes[] memory keyChain_) internal pure returns (bytes memory key_) {
        require(keyChain_.length > 0, EmptyKeyChain());

        // TODO: Perhaps compute the final size of the key and allocate the memory in one go.
        for (uint256 index_; index_ < keyChain_.length; ++index_) {
            key_ = index_ == 0 ? keyChain_[index_] : _combineKeyChainParts(key_, keyChain_[index_]);
        }
    }

    function _combineKeyChainParts(bytes memory left_, bytes memory right_) internal pure returns (bytes memory key_) {
        return abi.encodePacked(left_, _DOT, right_);
    }

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return _getParameterRegistryStorage().parameters[key_];
    }

    function _revertIfNotAdmin() internal view {
        require(isAdmin(msg.sender), NotAdmin());
    }
}
