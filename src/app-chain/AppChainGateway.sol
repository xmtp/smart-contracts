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

    /// @inheritdoc IAppChainGateway
    address public immutable parameterRegistry;

    /// @inheritdoc IAppChainGateway
    address public immutable settlementChainGateway;

    /// @inheritdoc IAppChainGateway
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

    /**
     * @notice Constructor.
     * @param  parameterRegistry_      The address of the parameter registry.
     * @param  settlementChainGateway_ The address of the settlement chain gateway.
     */
    constructor(address parameterRegistry_, address settlementChainGateway_) {
        require(_isNotZero(parameterRegistry = parameterRegistry_), ZeroParameterRegistryAddress());
        require(_isNotZero(settlementChainGateway = settlementChainGateway_), ZeroSettlementChainGatewayAddress());

        settlementChainGatewayAlias = AddressAliasHelper.applyL1ToL2Alias(settlementChainGateway_);

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IAppChainGateway
    function initialize() external initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IAppChainGateway
    function receiveParameters(
        uint256 nonce_,
        bytes[] calldata keys_,
        bytes32[] calldata values_
    ) external onlySettlementChainGateway {
        AppChainGatewayStorage storage $ = _getAppChainGatewayStorage();

        emit ParametersReceived(nonce_, keys_);

        for (uint256 index_; index_ < keys_.length; ++index_) {
            bytes calldata key_ = keys_[index_];

            // Each key is checked against the nonce, and ignored if the nonce is lower than the stored nonce.
            if ($.keyNonces[key_] >= nonce_) continue;

            $.keyNonces[key_] = nonce_;

            // slither-disable-next-line calls-loop
            IParameterRegistryLike(parameterRegistry).set(key_, values_[index_]);
        }
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(address(uint160(uint256(_getRegistryParameter(migratorParameterKey())))));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IAppChainGateway
    function migratorParameterKey() public pure virtual returns (bytes memory key_) {
        return "xmtp.appChainGateway.migrator";
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }

    function _revertIfNotSettlementChainGateway() internal view {
        require(msg.sender == settlementChainGatewayAlias, NotSettlementChainGateway());
    }
}
