// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { GenericEIP1967Migrator } from "../../../src/any-chain/GenericEIP1967Migrator.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { IMigratable } from "../../../src/abstract/interfaces/IMigratable.sol";
import { Utils } from "../../utils/Utils.sol";
import { FireblocksNote } from "../../utils/FireblocksNote.sol";
import { AdminAddressTypeLib } from "../../utils/AdminAddressType.sol";

/**
 * @notice Abstract base contract for upgrading proxy contracts
 * @dev Concrete upgraders must implement:
 *      - `_getProxy()` to return the proxy address from deployment data
 *      - `_deployOrGetImplementation()` to deploy or get the implementation address
 *      - `_getMigratorParameterKey()` to get the migrator parameter key
 *      - `_getContractState()` to capture contract state
 *      - `_isContractStateEqual()` to compare states
 *      - `_logContractState()` to log state information
 * @dev Admin address type is determined by environment with optional ADMIN_ADDRESS_TYPE override.
 *      See AdminAddressTypeLib for environment-specific defaults.
 * @dev Environment variables:
 *      - ADMIN_PRIVATE_KEY: Required when using WALLET mode (for setting migrator in parameter registry)
 *      - ADMIN: Required when using FIREBLOCKS mode (must match Fireblocks vault account address)
 *      - DEPLOYER_PRIVATE_KEY: Always required (for deploying implementations, migrators, and executing migrations)
 */
abstract contract BaseSettlementChainUpgrader is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error AdminNotSet();
    error StateMismatch();
    error StateComparisonNotImplemented();
    error UnexpectedChainId();

    string internal _environment;
    uint256 internal _adminPrivateKey;
    address internal _admin;
    AdminAddressTypeLib.AdminAddressType internal _adminAddressType;
    uint256 internal _deployerPrivateKey;
    address internal _deployer;
    Utils.DeploymentData internal _deployment;
    bool internal _skipStateCheck;
    string internal _fireblocksNote;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Deployment data
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        // Determine admin address type based on environment with optional override
        _adminAddressType = AdminAddressTypeLib.getAdminAddressType(_environment);

        // Admin setup (for setting migrator in parameter registry)
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            // Wallet mode: require ADMIN_PRIVATE_KEY
            _adminPrivateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
            if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
            _admin = vm.addr(_adminPrivateKey);
            console.log("Admin (Wallet): %s", _admin);
        } else {
            // Fireblocks mode: require ADMIN address (private key not needed)
            _admin = vm.envAddress("ADMIN");
            if (_admin == address(0)) revert AdminNotSet();
            console.log("Admin (Fireblocks): %s", _admin);
        }

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

        // Fireblocks note will be set per operation (Deploy/SetMigrator/PerformMigration)
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Fireblocks) {
            console.log("Fireblocks Note: Will be set per operation (Deploy/SetMigrator/PerformMigration)");
        }
    }

    /**
     * @notice Gets or generates a Fireblocks note for transaction tracking
     * @param operation_ The operation being performed (e.g., "upgrade")
     * @return note_ The Fireblocks note to use
     * @dev If FIREBLOCKS_NOTE env var is set, uses that. Otherwise generates a default note
     *      based on environment, contract name, and operation.
     */
    function _getFireblocksNote(string memory operation_) internal view returns (string memory note_) {
        string memory contractName = _getContractName();
        return FireblocksNote.getNote(_environment, operation_, contractName);
    }

    /**
     * @notice Gets the contract name for Fireblocks notes
     * @return name_ The contract name (e.g., "NodeRegistry")
     * @dev Tries to read contractName() from the proxy. Falls back to a default message
     *      if the function doesn't exist (older implementations).
     */
    function _getContractName() internal view returns (string memory name_) {
        address proxy = _getProxy();
        return FireblocksNote.getContractName(proxy);
    }

    /**
     * @notice Step 1 of 3: Deploy implementation and migrator
     * @dev Deploys or gets the implementation and creates a migrator (using DEPLOYER_PRIVATE_KEY)
     * @dev This step never uses Fireblocks, so no Fireblocks note is needed
     * @dev Outputs MIGRATOR_ADDRESS, FIREBLOCKS_NOTE, and FIREBLOCKS_EXTERNAL_TX_ID for Step 2.
     *      The external tx ID is a Fireblocks idempotency key that prevents duplicate transactions
     *      if forge retries the RPC call during the Fireblocks signing step.
     * @return migrator_ The deployed migrator address
     */
    function DeployImplementationAndMigrator() external returns (address migrator_) {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _getProxy();

        console.log("factory %s", factory);
        console.log("paramRegistry %s", paramRegistry);
        console.log("proxy %s", proxy);

        vm.startBroadcast(_deployerPrivateKey);

        // Deploy or get implementation
        address newImpl = _deployOrGetImplementation();
        console.log("newImpl %s", newImpl);

        // Deploy generic migrator
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator (also param reg migrator value) %s", address(migrator));

        vm.stopBroadcast();

        // Output migrator address, Fireblocks note, and external tx ID for step 2
        // Always output these, even if not using Fireblocks for Step 1, since user might use Fireblocks for Step 2
        string memory fireblocksNote = _getFireblocksNote("setMigrator");
        string memory externalTxId = string.concat(
            "setMigrator-",
            _getContractName(),
            "-",
            _environment,
            "-",
            vm.toString(vm.unixTime())
        );
        console.log("==========================================");
        console.log("MIGRATOR_ADDRESS_FOR_STEP_2: %s", address(migrator));
        console.log("FIREBLOCKS_NOTE_FOR_STEP_2: %s", fireblocksNote);
        console.log("Export these values before running Step 2:");
        console.log("  export MIGRATOR_ADDRESS=%s", address(migrator));
        console.log('  export FIREBLOCKS_NOTE="%s"', fireblocksNote);
        console.log('  export FIREBLOCKS_EXTERNAL_TX_ID="%s"', externalTxId);
        console.log("==========================================");

        return address(migrator);
    }

    /**
     * @notice Step 2 of 3: Set migrator in parameter registry
     * @param migrator_ The migrator address from step 1
     * @dev Sets the migrator in parameter registry using ADMIN (PRIVATE_KEY or FIREBLOCKS based on environment)
     */
    function SetMigratorInParameterRegistry(address migrator_) external {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        // Set Fireblocks note for this operation
        _fireblocksNote = _getFireblocksNote("setMigrator");
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Fireblocks) {
            console.log("Fireblocks Note: %s", _fireblocksNote);
        }

        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _getProxy();

        console.log("paramRegistry %s", paramRegistry);
        console.log("proxy %s", proxy);
        console.log("migrator %s", migrator_);

        // Set migrator in parameter registry (using ADMIN)
        string memory key = _getMigratorParameterKey(proxy);
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(migrator_))));
        console.log("param reg migrator key %s", key);
        vm.stopBroadcast();
    }

    /**
     * @notice Step 3 of 3: Perform migration
     * @dev Executes the migration and verifies state preservation (using DEPLOYER_PRIVATE_KEY)
     * @dev This step never uses Fireblocks, so no Fireblocks note is needed
     */
    function PerformMigration() external {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address proxy = _getProxy();

        console.log("proxy %s", proxy);

        // Get contract state before upgrade
        bytes memory stateBefore = _getContractState(proxy);
        _logContractState("State before upgrade:", stateBefore);

        // Perform migration (using DEPLOYER)
        vm.startBroadcast(_deployerPrivateKey);
        IMigratable(proxy).migrate();
        vm.stopBroadcast();

        // Compare state before and after upgrade
        bytes memory stateAfter = _getContractState(proxy);
        if (stateBefore.length == 0 || stateAfter.length == 0) {
            revert StateComparisonNotImplemented();
        }
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
     * @notice Performs the upgrade process (all-in-one for non-Fireblocks environments)
     * @dev This function handles the common upgrade flow:
     *      1. Deploys or gets the implementation (using DEPLOYER_PRIVATE_KEY)
     *      2. Creates a GenericEIP1967Migrator (using DEPLOYER_PRIVATE_KEY)
     *      3. Sets the migrator in the parameter registry (using ADMIN - PRIVATE_KEY or FIREBLOCKS based on environment)
     *      4. Executes the migration (using DEPLOYER_PRIVATE_KEY)
     *      5. Compares state before and after
     * @dev For Fireblocks environments, use the three-step process instead:
     *      - DeployImplementationAndMigrator()
     *      - SetMigratorInParameterRegistry(address)
     *      - PerformMigration()
     */
    function Upgrade() external {
        _upgrade();
    }

    /**
     * @notice Internal upgrade function that performs all upgrade steps
     * @dev This is called by Upgrade() and can be overridden by child contracts if needed
     */
    function _upgrade() internal virtual {
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

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
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }
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
