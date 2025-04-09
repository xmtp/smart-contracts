// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IAppChainGateway } from "./interfaces/IAppChainGateway.sol";

import { Migratable } from "../abstract/Migratable.sol";

contract AppChainGateway is IAppChainGateway, Migratable, Initializable {
    /* ============ Constants/Immutables ============ */

    bytes internal constant _DELIMITER = bytes(".");

    address public immutable registry;
    address public immutable settlementChainGateway;
    address public immutable settlementChainGatewayAlias;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.AppChainGateway
    struct AppChainGatewayStorage {
        mapping(bytes key => uint256 nonce) keyNonces;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.AppChainGateway")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _APP_CHAIN_GATEWAY_STORAGE_LOCATION =
        0xf7630100a9c96f7b07fb982ff1e6dad8abbb961bacff2e820fac4ea93b280300;

    function _getAppChainGatewayStorage() internal pure returns (AppChainGatewayStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _APP_CHAIN_GATEWAY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier onlySettlementChainGateway() {
        _revertIfNotSettlementChainGateway();
        _;
    }

    /* ============ Constructor ============ */

    constructor(address registry_, address settlementChainGateway_) {
        require(_isNotZero(registry = registry_), ZeroRegistryAddress());
        require(_isNotZero(settlementChainGateway = settlementChainGateway_), ZeroSettlementChainGatewayAddress());

        settlementChainGatewayAlias = AddressAliasHelper.applyL1ToL2Alias(settlementChainGateway_);
    }

    /* ============ Initialization ============ */

    function initialize() external initializer {
        // TODO: If nothing to initialize, consider `_disableInitializers()` in constructor.
    }

    /* ============ Interactive Functions ============ */

    function receiveParameters(
        uint256 nonce_,
        bytes[][] calldata keyChains_,
        bytes32[] calldata values_
    ) external onlySettlementChainGateway {
        AppChainGatewayStorage storage $ = _getAppChainGatewayStorage();

        emit ParametersReceived(nonce_, keyChains_);

        for (uint256 index_; index_ < keyChains_.length; ++index_) {
            bytes[] calldata keyChain_ = keyChains_[index_];
            bytes memory key_ = _getKey(keyChain_);

            if ($.keyNonces[key_] >= nonce_) continue;

            $.keyNonces[key_] = nonce_;

            IParameterRegistryLike(registry).set(keyChain_, values_[index_]);
        }
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(address(uint160(uint256(_getRegistryParameter(migratorParameterKey())))));
    }

    /* ============ View/Pure Functions ============ */

    function migratorParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.acg.migrator";
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
        return abi.encodePacked(left_, _DELIMITER, right_);
    }

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        bytes[] memory keyChain_ = new bytes[](1);
        keyChain_[0] = key_;

        return IParameterRegistryLike(registry).get(keyChain_);
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        isNotZero_ = input_ != address(0);
    }

    function _revertIfNotSettlementChainGateway() internal view {
        require(msg.sender == settlementChainGatewayAlias, NotSettlementChainGateway());
    }
}
