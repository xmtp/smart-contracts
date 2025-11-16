// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IVersioned } from "../../abstract/interfaces/IVersioned.sol";

/**
 * @title Interface for a Factory contract that deterministically deploys implementations and proxies.
 */
interface IFactory is IMigratable, IVersioned {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the "initializable implementation" is deployed.
     * @param  implementation The address of the deployed "initializable implementation".
     * @dev    This contract is only deployed once, when the factory itself is deployed.
     */
    event InitializableImplementationDeployed(address indexed implementation);

    /**
     * @notice Emitted when an implementation is deployed.
     * @param  implementation The address of the deployed implementation.
     * @param  bytecodeHash   The hash of the bytecode of the deployed implementation.
     */
    event ImplementationDeployed(address indexed implementation, bytes32 indexed bytecodeHash);

    /**
     * @notice Emitted when a proxy is deployed.
     * @param  proxy              The address of the deployed proxy.
     * @param  implementation     The address of the implementation the proxy proxies.
     * @param  sender             The address of the sender that triggered the proxy deployment.
     * @param  salt               The salt defined by the sender.
     * @param  initializeCallData The call data used to initialize the proxy.
     * @dev    The actual salt used to deploy the proxy via `create2` is `keccak256(abi.encodePacked(sender, salt))`.
     */
    event ProxyDeployed(
        address indexed proxy,
        address indexed implementation,
        address indexed sender,
        bytes32 salt,
        bytes initializeCallData
    );

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry is the zero address.
    error ZeroParameterRegistry();

    /// @notice Thrown when the implementation is the zero address.
    error InvalidImplementation();

    /// @notice Thrown when the bytecode is empty (i.e. of the implementation to deploy).
    error EmptyBytecode();

    /// @notice Thrown when the deployment of a contract (e.g. an implementation or proxy) fails.
    error DeployFailed();

    /// @notice Thrown when any pausable function is called when the contract is paused.
    error Paused();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deploys an implementation contract.
     * @param  bytecode_       The bytecode of the implementation to deploy (including appended constructor data).
     * @return implementation_ The address of the deployed implementation.
     */
    function deployImplementation(bytes memory bytecode_) external returns (address implementation_);

    /**
     * @notice Deploys a proxy contract.
     * @param  implementation_     The address of the implementation the proxy should proxy.
     * @param  salt_               A salt defined by the sender.
     * @param  initializeCallData_ The call data used to initialize the proxy.
     * @return proxy_              The address of the deployed proxy.
     */
    function deployProxy(
        address implementation_,
        bytes32 salt_,
        bytes calldata initializeCallData_
    ) external returns (address proxy_);

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the paused status.
    function pausedParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /**
     * @notice The address of the first temporary implementation that proxies will proxy.
     * @dev    This contract is the first proxied implementation of any proxy, and allows the factory to then set the
     *         proxy's actual implementation, and initialize it with respect to that actual implementation.
     *         This ensures that:
     *           - The address of a proxy is only defined by the nonce, and not by the implementation it will proxy.
     *           - No contracts are deployed that are not used.
     *           - The proxy can be easily initialized with respect to the actual implementation, atomically.
     */
    function initializableImplementation() external view returns (address initializableImplementation_);

    /**
     * @notice Computes the address of an implementation contract that would be deployed from a given bytecode.
     * @param  bytecode_       The bytecode of the implementation to deploy (including appended constructor data).
     * @return implementation_ The address of the implementation that would be deployed.
     * @dev    The address is determined only by the bytecode, and so the same bytecode results in the same address.
     */
    function computeImplementationAddress(bytes calldata bytecode_) external view returns (address implementation_);

    /**
     * @notice Computes the address of a proxy contract that would be deployed from given a caller and salt.
     * @param  caller_ The address of the caller that would request the proxy deployment.
     * @param  salt_   The salt defined by the caller.
     * @return proxy_  The address of the proxy that would be deployed.
     * @dev    The actual salt used to deploy the proxy via `create2` is `keccak256(abi.encodePacked(caller_, salt_))`.
     */
    function computeProxyAddress(address caller_, bytes32 salt_) external view returns (address proxy_);
}
