// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AddressAliasHelper } from "../../lib/arbitrum-bridging/contracts/tokenbridge/libraries/AddressAliasHelper.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IAppChainGateway } from "./interfaces/IAppChainGateway.sol";

import { Migratable } from "../abstract/Migratable.sol";

// TODO: Message ordering.
// TODO: Admin set/reset and event.

contract AppChainGateway is IAppChainGateway, Migratable, Initializable {
    /* ============ Constants ============ */

    address public immutable registry;
    address public immutable settlementChainGateway;
    address public immutable settlementChainGatewayAlias;

    /* ============ UUPS Storage ============ */

    /// @custom:storage-location erc7201:xmtp.storage.AppChainGateway
    struct AppChainGatewayStorage {
        uint256 _placeholder;
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
        bytes[][] calldata keyChains_,
        bytes32[] calldata values_
    ) external onlySettlementChainGateway {
        IParameterRegistryLike(registry).set(keyChains_, values_);
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
