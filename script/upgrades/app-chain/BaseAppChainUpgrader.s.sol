// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { GenericEIP1967Migrator } from "../../../src/any-chain/GenericEIP1967Migrator.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { ISettlementChainGateway } from "../../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IMigratable } from "../../../src/abstract/interfaces/IMigratable.sol";
import { IERC20Like } from "../../Interfaces.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @notice Base contract for app chain upgrade scripts
 * @dev Concrete upgraders must implement:
 *      - `_getProxy()` to return the proxy address from deployment data
 *      - `_getContractName()` to return the contract name for parameter keys
 *      - `_getImplementationAddress()` to get the implementation address from the proxy
 *      - `_deployOrGetImplementation()` to deploy or get the implementation address
 *      - `_getContractState()` to capture contract state
 *      - `_isContractStateEqual()` to compare states
 *      - `_logContractState()` to log state information
 * @dev Requires both ADMIN_PRIVATE_KEY and DEPLOYER_PRIVATE_KEY environment variables:
 *      - ADMIN_PRIVATE_KEY: Used only for setting the migrator parameter in the parameter registry
 *      - DEPLOYER_PRIVATE_KEY: Used for deploying implementations, migrators, executing migrations, and bridging parameters
 */
abstract contract BaseAppChainUpgrader is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error GatewayProxyNotSet();
    error UnexpectedChainId();
    error InsufficientBalance();
    error StateMismatch();

    uint256 internal constant _TX_STIPEND = 21_000;
    uint256 internal constant _GAS_PER_BRIDGED_KEY = 75_000;

    /// @dev Default value copied from Administration.s.sol
    /// On app chain, each gas unit costs 2 gwei (measured as fraction of the xUSD native token).
    /// Arbitrum L3 default is 0.1 gwei, but this fluctuates with demand.
    uint256 internal constant _APP_CHAIN_GAS_PRICE = 2_000_000_000;

    string internal _environment;
    uint256 internal _adminPrivateKey;
    address internal _admin;
    uint256 internal _deployerPrivateKey;
    address internal _deployer;
    Utils.DeploymentData internal _deployment;

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
    }

    /**
     * @notice Step 1 of 3: Prepare the upgrade on the app chain
     * @dev Deploys or gets the implementation and creates a migrator (using DEPLOYER_PRIVATE_KEY)
     */
    function Prepare() external {
        if (block.chainid != _deployment.appChainId) revert UnexpectedChainId();

        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _getProxy();

        console.log("factory: %s", factory);
        console.log("paramRegistry: %s", paramRegistry);
        console.log("proxy: %s", proxy);

        vm.startBroadcast(_deployerPrivateKey);

        // Deploy or get implementation
        address newImpl = _deployOrGetImplementation(factory, paramRegistry, proxy);
        console.log("newImpl: %s", newImpl);

        // Deploy generic migrator
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator: %s", address(migrator));

        vm.stopBroadcast();

        // Output migrator address for step 2
        console.log("==========================================");
        console.log("MIGRATOR_ADDRESS_FOR_STEP_2: %s", address(migrator));
        console.log("==========================================");
    }

    /**
     * @notice Step 2 of 3: Bridge the migrator parameter from settlement chain to app chain
     * @param migrator_ The migrator address from step 1
     * @dev Sets the migrator in parameter registry using ADMIN_PRIVATE_KEY,
     *      then approves fee token and bridges the parameter using DEPLOYER_PRIVATE_KEY
     */
    function Bridge(address migrator_) external {
        if (_deployment.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _deployment.gatewayProxy;

        console.log("paramRegistry: %s", paramRegistry);
        console.log("gatewayProxy (settlement chain): %s", proxy);
        console.log("migrator: %s", migrator_);
        console.log("appChainId: %s", _deployment.appChainId);

        // Get migrator parameter key
        string memory key = _getMigratorParameterKey();
        console.log("migratorParameterKey: %s", key);

        // Set migrator in parameter registry (using ADMIN)
        vm.startBroadcast(_adminPrivateKey);
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(migrator_))));
        console.log("Set migrator in parameter registry");
        vm.stopBroadcast();

        // Calculate gas and cost for bridging
        // The value 1 below is the number of parameter keys being bridged
        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * 1);

        // Convert from 18 decimals (app chain gas token) to 6 decimals (fee token).
        uint256 cost_ = ((_APP_CHAIN_GAS_PRICE * gasLimit_) * 1e6) / 1e18;

        console.log("gasLimit: %s", gasLimit_);
        console.log("cost (fee token, 6 decimals): %s", cost_);

        // Approve fee token and bridge (using DEPLOYER)
        vm.startBroadcast(_deployerPrivateKey);
        if (IERC20Like(_deployment.feeTokenProxy).balanceOf(_deployer) < cost_) revert InsufficientBalance();

        // Approve fee token
        IERC20Like(_deployment.feeTokenProxy).approve(proxy, cost_);

        // Bridge the parameter
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = _deployment.appChainId;

        string[] memory keys_ = new string[](1);
        keys_[0] = key;

        ISettlementChainGateway(proxy).sendParameters(chainIds_, keys_, gasLimit_, _APP_CHAIN_GAS_PRICE, cost_);

        console.log("Bridged migrator parameter to app chain");

        vm.stopBroadcast();
    }

    /**
     * @notice Step 3 of 3: Perform the upgrade on the app chain
     * @dev Executes the migration and verifies state preservation (using DEPLOYER_PRIVATE_KEY)
     */
    function Upgrade() external {
        address proxy = _getProxy();

        console.log("proxy: %s", proxy);

        // Get implementation address before upgrade
        address implBefore = _getImplementationAddress(proxy);
        console.log("Implementation before upgrade: %s", implBefore);

        // Get contract state before upgrade
        bytes memory stateBefore = _getContractState(proxy);
        _logContractState("State before upgrade:", stateBefore);

        vm.startBroadcast(_deployerPrivateKey);

        // Perform migration
        IMigratable(proxy).migrate();
        console.log("Migration completed");

        vm.stopBroadcast();

        // Get implementation address after upgrade
        address implAfter = _getImplementationAddress(proxy);
        console.log("Implementation after upgrade: %s", implAfter);

        // Compare state before and after upgrade
        bytes memory stateAfter = _getContractState(proxy);
        _logContractState("State after upgrade:", stateAfter);

        if (!_isContractStateEqual(stateBefore, stateAfter)) revert StateMismatch();

        console.log("State comparison passed - upgrade successful!");
    }

    /**
     * @notice Gets the proxy address from deployment data
     * @return proxy_ The proxy address
     */
    function _getProxy() internal view virtual returns (address proxy_);

    /**
     * @notice Gets the contract name for parameter key generation
     * @return name_ The contract name (e.g., "appChainGateway")
     */
    function _getContractName() internal pure virtual returns (string memory name_);

    /**
     * @notice Gets the migrator parameter key
     * @return key_ The migrator parameter key (e.g., "xmtp.appChainGateway.migrator")
     */
    function _getMigratorParameterKey() internal pure returns (string memory key_) {
        return string.concat("xmtp.", _getContractName(), ".migrator");
    }

    /**
     * @notice Gets the implementation address from a proxy
     * @param proxy_ The proxy address
     * @return impl_ The implementation address
     * @dev Must be implemented by all upgraders to read the implementation address from the proxy
     */
    function _getImplementationAddress(address proxy_) internal view virtual returns (address impl_);

    /**
     * @notice Deploys or gets the implementation address
     * @param factory_ The factory address
     * @param paramRegistry_ The parameter registry address
     * @param proxy_ The proxy address (for reading current state if needed)
     * @return implementation_ The implementation address
     * @dev Should check if implementation already exists at computed address before deploying
     */
    function _deployOrGetImplementation(
        address factory_,
        address paramRegistry_,
        address proxy_
    ) internal virtual returns (address implementation_);

    /**
     * @notice Gets the contract state before/after upgrade
     * @param proxy_ The proxy address
     * @return state_ Encoded state data
     */
    function _getContractState(address proxy_) internal view virtual returns (bytes memory state_);

    /**
     * @notice Compares contract state before and after upgrade
     * @param stateBefore_ Encoded state before upgrade
     * @param stateAfter_ Encoded state after upgrade
     * @return isEqual_ Whether the states are equal
     */
    function _isContractStateEqual(
        bytes memory stateBefore_,
        bytes memory stateAfter_
    ) internal pure virtual returns (bool isEqual_);

    /**
     * @notice Logs the contract state
     * @param title_ Title for the log
     * @param state_ Encoded state data
     */
    function _logContractState(string memory title_, bytes memory state_) internal view virtual;
}
