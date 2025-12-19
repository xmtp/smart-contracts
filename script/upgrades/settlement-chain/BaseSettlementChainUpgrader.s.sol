// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { GenericEIP1967Migrator } from "../../../src/any-chain/GenericEIP1967Migrator.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { IMigratable } from "../../../src/abstract/interfaces/IMigratable.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @notice Abstract base contract for upgrading proxy contracts
 * @dev Concrete upgraders must implement:
 *      - `_getProxy()` to return the proxy address from deployment data
 *      - `_deployOrGetImplementation()` to deploy or get the implementation address
 *      - `_getMigratorParameterKey()` to get the migrator parameter key
 *      - `_getContractState()` to capture contract state
 *      - `_isContractStateEqual()` to compare states
 *      - `_logContractState()` to log state information
 * @dev Requires both ADMIN_PRIVATE_KEY and DEPLOYER_PRIVATE_KEY environment variables:
 *      - ADMIN_PRIVATE_KEY: Used only for setting the migrator parameter in the parameter registry
 *      - DEPLOYER_PRIVATE_KEY: Used for deploying implementations, migrators, and executing migrations
 */
abstract contract BaseSettlementChainUpgrader is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error StateMismatch();
    error StateComparisonNotImplemented();

    string internal _environment;
    uint256 internal _adminPrivateKey;
    address internal _admin;
    uint256 internal _deployerPrivateKey;
    address internal _deployer;
    Utils.DeploymentData internal _deployment;
    bool internal _skipStateCheck;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Deployment data
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        // Admin private key (for setting migrator in parameter registry)
        _adminPrivateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
        if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
        _admin = vm.addr(_adminPrivateKey);
        console.log("Admin: %s", _admin);

        // Deployer private key (for deploying implementations, migrators, and executing migrations)
        _deployerPrivateKey = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
        if (_deployerPrivateKey == 0) revert PrivateKeyNotSet();
        _deployer = vm.addr(_deployerPrivateKey);
        console.log("Deployer: %s", _deployer);

        // Optional: Skip state check flag (for intentional state changes like parameter registry updates)
        try vm.envBool("SKIP_STATE_CHECK") returns (bool skip_) {
            _skipStateCheck = skip_;
            if (_skipStateCheck) {
                console.log("WARNING: State check is DISABLED - proceeding with upgrade even if state mismatches");
            }
        } catch {
            _skipStateCheck = false;
        }
    }

    /**
     * @notice Performs the upgrade process
     * @dev This function handles the common upgrade flow:
     *      1. Deploys or gets the implementation (using DEPLOYER_PRIVATE_KEY)
     *      2. Creates a GenericEIP1967Migrator (using DEPLOYER_PRIVATE_KEY)
     *      3. Sets the migrator in the parameter registry (using ADMIN_PRIVATE_KEY)
     *      4. Executes the migration (using DEPLOYER_PRIVATE_KEY)
     *      5. Compares state before and after
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

        // Deploy or get implementation (using DEPLOYER)
        vm.startBroadcast(_deployerPrivateKey);
        address newImpl = _deployOrGetImplementation();
        console.log("newImpl %s", newImpl);

        // Deploy generic migrator (using DEPLOYER)
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator (also param reg migrator value) %s", address(migrator));
        vm.stopBroadcast();

        // Set migrator in parameter registry (using ADMIN)
        string memory key = _getMigratorParameterKey(proxy);
        vm.startBroadcast(_adminPrivateKey);
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(address(migrator)))));
        console.log("param reg migrator key %s", key);
        vm.stopBroadcast();

        // Perform migration (using DEPLOYER)
        vm.startBroadcast(_deployerPrivateKey);
        IMigratable(proxy).migrate();
        vm.stopBroadcast();

        // Compare state before and after upgrade
        bytes memory stateAfter = _getContractState(proxy);
        if (stateBefore.length == 0 || stateAfter.length == 0) {
            revert StateComparisonNotImplemented();
        }
        _logContractState("State before upgrade:", stateBefore);
        _logContractState("State after upgrade:", stateAfter);
        bool statesEqual = _isContractStateEqual(stateBefore, stateAfter);
        if (!statesEqual) {
            if (_skipStateCheck) {
                console.log("WARNING: State mismatch detected but SKIP_STATE_CHECK is enabled - proceeding anyway");
            } else {
                revert StateMismatch();
            }
        } else {
            console.log("State check passed: all state values match");
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
     * @return state_ Encoded state data
     * @dev Must be implemented by all upgraders. Must return non-empty bytes for state comparison.
     */
    function _getContractState(address proxy_) internal view virtual returns (bytes memory state_);

    /**
     * @notice Compares contract state before and after upgrade
     * @param stateBefore_ Encoded state before upgrade
     * @param stateAfter_ Encoded state after upgrade
     * @return isEqual_ Whether the states are equal
     * @dev Must be implemented by all upgraders.
     */
    function _isContractStateEqual(
        bytes memory stateBefore_,
        bytes memory stateAfter_
    ) internal pure virtual returns (bool isEqual_);

    /**
     * @notice Logs the contract state
     * @param title_ Title for the log
     * @param state_ Encoded state data
     * @dev Must be implemented by all upgraders.
     */
    function _logContractState(string memory title_, bytes memory state_) internal view virtual;
}
