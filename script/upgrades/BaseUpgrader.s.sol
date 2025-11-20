// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../lib/forge-std/src/Script.sol";
import { GenericEIP1967Migrator } from "../../src/any-chain/GenericEIP1967Migrator.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { IMigratable } from "../../src/abstract/interfaces/IMigratable.sol";
import { Utils } from "../utils/Utils.sol";

/**
 * @notice Abstract base contract for upgrading proxy contracts
 * @dev Concrete upgraders must implement:
 *      - `_getProxy()` to return the proxy address from deployment data
 *      - `_deployOrGetImplementation()` to deploy or get the implementation address
 *      - `_getMigratorParameterKey()` to get the migrator parameter key
 *      - `_getContractState()` to capture contract state (return empty bytes to skip comparison)
 *      - `_isContractStateEqual()` to compare states
 *      - `_logContractState()` to log state information
 */
abstract contract BaseUpgrader is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error StateMismatch();
    error StateComparisonNotImplemented();

    string internal _environment;
    uint256 internal _privateKey;
    address internal _admin;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Admin private key
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));
        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
        if (_privateKey == 0) revert PrivateKeyNotSet();
        _admin = vm.addr(_privateKey);
        console.log("Admin: %s", _admin);
    }

    /**
     * @notice Performs the upgrade process
     * @dev This function handles the common upgrade flow:
     *      1. Deploys or gets the implementation
     *      2. Creates a GenericEIP1967Migrator
     *      3. Sets the migrator in the parameter registry
     *      4. Executes the migration
     *      5. Optionally compares state before and after
     */
    function _upgrade() internal {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _getProxy();

        console.log("factory %s", factory);
        console.log("paramRegistry %s", paramRegistry);
        console.log("proxy %s", proxy);

        // Get contract state before upgrade
        bytes memory stateBefore = _getContractState(proxy);

        vm.startBroadcast(_privateKey);

        // Deploy or get implementation
        address newImpl = _deployOrGetImplementation();
        console.log("newImpl %s", newImpl);

        // Deploy generic migrator
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator (also param reg migrator value) %s", address(migrator));

        // Set migrator in parameter registry
        string memory key = _getMigratorParameterKey(proxy);
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));
        console.log("param reg migrator key %s", key);

        // Perform migration
        IMigratable(proxy).migrate();

        vm.stopBroadcast();

        // Compare state before and after upgrade
        bytes memory stateAfter = _getContractState(proxy);
        if (stateBefore.length > 0 && stateAfter.length > 0) {
            _logContractState("State before upgrade:", stateBefore);
            _logContractState("State after upgrade:", stateAfter);
            if (!_isContractStateEqual(stateBefore, stateAfter)) revert StateMismatch();
        } else {
            revert StateComparisonNotImplemented();
        }
    }

    /**
     * @notice Gets the proxy address from deployment data
     * @return proxy_ The proxy address
     */
    function _getProxy() internal view virtual returns (address proxy_);

    /**
     * @notice Deploys or gets the implementation address
     * @return implementation_ The implementation address
     * @dev Should check if implementation already exists at computed address before deploying
     */
    function _deployOrGetImplementation() internal virtual returns (address implementation_);

    /**
     * @notice Gets the migrator parameter key from the proxy contract
     * @param proxy_ The proxy address
     * @return key_ The migrator parameter key
     */
    function _getMigratorParameterKey(address proxy_) internal view virtual returns (string memory key_);

    /**
     * @notice Gets the contract state before/after upgrade
     * @param proxy_ The proxy address
     * @return state_ Encoded state data (return empty bytes to skip state comparison)
     * @dev Must be implemented by all upgraders. Return empty bytes if state comparison is not needed.
     */
    function _getContractState(address proxy_) internal view virtual returns (bytes memory state_);

    /**
     * @notice Compares contract state before and after upgrade
     * @param stateBefore_ Encoded state before upgrade
     * @param stateAfter_ Encoded state after upgrade
     * @return isEqual_ Whether the states are equal
     * @dev Must be implemented by all upgraders. Only called if both states are non-empty.
     */
    function _isContractStateEqual(
        bytes memory stateBefore_,
        bytes memory stateAfter_
    ) internal pure virtual returns (bool isEqual_);

    /**
     * @notice Logs the contract state
     * @param title_ Title for the log
     * @param state_ Encoded state data
     * @dev Must be implemented by all upgraders. Only called if state is non-empty.
     */
    function _logContractState(string memory title_, bytes memory state_) internal view virtual;
}
