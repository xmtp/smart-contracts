// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Create2 } from "../../lib/oz/contracts/utils/Create2.sol";

import { Initializable as OZInitializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IFactory } from "./interfaces/IFactory.sol";
import { IInitializable } from "./interfaces/IInitializable.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IVersioned } from "../abstract/interfaces/IVersioned.sol";

import { Initializable } from "./Initializable.sol";
import { Migratable } from "../abstract/Migratable.sol";
import { Proxy } from "./Proxy.sol";

/**
 * @title  Factory contract that deterministically deploys implementations and proxies.
 * @notice This contract is used to deploy implementations and proxies deterministically, using `create2`, and is to
 *         only be deployed once on each chain. Implementations deployed use their own bytecode hash as their salt, so
 *         a unique bytecode (including constructor arguments) will have only one possible address. Proxies deployed use
 *         the sender's address combined with a salt of the sender's choosing as a final salt, and the constructor
 *         arguments are always the same (i.e. the "initializable implementation"), so an address has only 2 degrees
 *         of freedom. This is helpful for ensuring the address of a future/planned contract is constant, while the
 *         implementation is not yet finalized or deployed.
 */
contract Factory is IFactory, Migratable, OZInitializable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IFactory
    address public immutable parameterRegistry;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.Factory
     * @notice The UUPS storage for the factory.
     * @param  paused The pause status.
     */
    struct FactoryStorage {
        bool paused;
        address initializableImplementation;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.Factory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _FACTORY_STORAGE_LOCATION =
        0x651b031aaeb8a5a65735ac2bad4001a08e08ce7e1a4736b27ec7d04baeb8f600;

    function _getFactoryStorage() internal pure returns (FactoryStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _FACTORY_STORAGE_LOCATION
        }
    }

    /* ============ Modifiers ============ */

    modifier whenNotPaused() {
        _revertIfPaused();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor that deploys the initializable implementation.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @dev    The parameter registry must not be the zero address.
     */
    constructor(address parameterRegistry_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IFactory
    function initialize() external initializer {
        emit InitializableImplementationDeployed(
            _getFactoryStorage().initializableImplementation = address(new Initializable())
        );
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IFactory
    function deployImplementation(bytes calldata bytecode_) external whenNotPaused returns (address implementation_) {
        if (bytecode_.length == 0) revert EmptyBytecode();

        bytes32 bytecodeHash_ = keccak256(bytecode_);

        // NOTE: Since an implementation is expected to be proxied, it can be a singleton, so its address can depend
        //       entirely on its bytecode, thus a unique bytecode will have only one possible address. Because of this,
        //       it does not matter who deploys the specific bytecode implementation, or if the call is frontrun.
        emit ImplementationDeployed(implementation_ = _create2(bytecode_, bytecodeHash_), bytecodeHash_);
    }

    /// @inheritdoc IFactory
    function deployProxy(
        address implementation_,
        bytes32 salt_,
        bytes calldata initializeCallData_
    ) external whenNotPaused returns (address proxy_) {
        if (_isZero(implementation_)) revert InvalidImplementation();

        // Append the initializable implementation address as a constructor argument to the proxy deploy code, and use
        // the sender's address combined with their chosen salt as the final salt.
        proxy_ = _create2(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(_getFactoryStorage().initializableImplementation)),
            keccak256(abi.encode(msg.sender, salt_))
        );

        emit ProxyDeployed(proxy_, implementation_, msg.sender, salt_, initializeCallData_);

        // Initialize the proxy, which will set its intended implementation slot and initialize it.
        IInitializable(proxy_).initialize(implementation_, initializeCallData_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IFactory
    function pausedParameterKey() public pure returns (string memory key_) {
        return "xmtp.factory.paused";
    }

    /// @inheritdoc IFactory
    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.factory.migrator";
    }

    /// @inheritdoc IFactory
    function paused() external view returns (bool paused_) {
        return _getFactoryStorage().paused;
    }

    /// @inheritdoc IFactory
    function initializableImplementation() external view returns (address initializableImplementation_) {
        return _getFactoryStorage().initializableImplementation;
    }

    /// @inheritdoc IFactory
    function computeImplementationAddress(bytes calldata bytecode_) external view returns (address implementation_) {
        bytes32 bytecodeHash_ = keccak256(bytecode_);
        return Create2.computeAddress(bytecodeHash_, bytecodeHash_);
    }

    /// @inheritdoc IFactory
    function computeProxyAddress(address caller_, bytes32 salt_) external view returns (address proxy_) {
        bytes memory initCode_ = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(_getFactoryStorage().initializableImplementation)
        );
        return Create2.computeAddress(keccak256(abi.encode(caller_, salt_)), keccak256(initCode_));
    }

    /// @inheritdoc IVersioned
    function version() external pure returns (string memory version_) {
        return "0.1.0";
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Creates a contract via `create2` and reverts if the deployment fails.
    function _create2(bytes memory bytecode_, bytes32 salt_) internal returns (address deployed_) {
        // slither-disable-next-line assembly
        assembly {
            deployed_ := create2(0, add(bytecode_, 0x20), mload(bytecode_), salt_)
        }

        if (_isZero(deployed_)) revert DeployFailed();
    }

    /* ============ Internal View/Pure Functions ============ */

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfPaused() internal view {
        if (_getFactoryStorage().paused) revert Paused();
    }
}
