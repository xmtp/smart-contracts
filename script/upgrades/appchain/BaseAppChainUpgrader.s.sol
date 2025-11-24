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
 *      - `_deployOrGetImplementation()` to deploy or get the implementation address (step 1 only)
 *      - `_getContractState()` to capture contract state (step 3 only, optional for step 1)
 *      - `_isContractStateEqual()` to compare states (step 3 only)
 *      - `_logContractState()` to log state information (step 3 only, optional override)
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
    uint256 internal constant _APP_CHAIN_GAS_PRICE = 2_000_000_000; // 2 gwei per gas

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
     * @notice Step 1 of 3: Prepare the upgrade on the app chain
     * @dev Deploys or gets the implementation and creates a migrator
     */
    function Prepare() external {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _getProxy();

        console.log("factory: %s", factory);
        console.log("paramRegistry: %s", paramRegistry);
        console.log("proxy: %s", proxy);

        vm.startBroadcast(_privateKey);

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

        vm.startBroadcast(_privateKey);

        // Set migrator in parameter registry
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(migrator_))));
        console.log("Set migrator in parameter registry");

        // Calculate gas and cost for bridging
        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * 1); // 1 key

        // Convert from 18 decimals (app chain gas token) to 6 decimals (fee token).
        uint256 cost_ = ((_APP_CHAIN_GAS_PRICE * gasLimit_) * 1e6) / 1e18;

        console.log("gasLimit: %s", gasLimit_);
        console.log("cost (fee token, 6 decimals): %s", cost_);

        if (IERC20Like(_deployment.feeTokenProxy).balanceOf(_admin) < cost_) revert InsufficientBalance();

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
     * @dev Executes the migration and verifies state preservation
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

        vm.startBroadcast(_privateKey);

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
     * @dev This is a helper that can be overridden if the contract has a different way to get the implementation
     */
    function _getImplementationAddress(address proxy_) internal view virtual returns (address impl_) {
        // Default implementation: try to call implementation() on the proxy
        // This works for contracts that expose an implementation() function
        (bool success, bytes memory data) = proxy_.staticcall(abi.encodeWithSignature("implementation()"));
        if (success && data.length >= 32) {
            return abi.decode(data, (address));
        }
        // If that fails, try to read from EIP-1967 storage slot
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 value;
        assembly {
            value := sload(slot)
        }
        return address(uint160(uint256(value)));
    }

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
     * @dev Default implementation returns empty bytes. Override in step 3 scripts to capture actual state.
     */
    function _getContractState(address) internal view virtual returns (bytes memory state_) {
        // Default: return empty bytes. Step 3 scripts should override this.
        return "";
    }

    /**
     * @notice Compares contract state before and after upgrade
     * @param stateBefore_ Encoded state before upgrade
     * @param stateAfter_ Encoded state after upgrade
     * @return isEqual_ Whether the states are equal
     * @dev Default implementation returns true. Override in step 3 scripts to perform actual comparison.
     */
    function _isContractStateEqual(
        bytes memory,
        bytes memory
    ) internal pure virtual returns (bool isEqual_) {
        // Default: return true. Step 3 scripts should override this.
        return true;
    }

    /**
     * @notice Logs the contract state
     * @param title_ Title for the log
     * @param state_ Encoded state data
     * @dev Default implementation is a no-op. Override in step 3 scripts to provide actual logging.
     */
    function _logContractState(string memory, bytes memory) internal view virtual {
        // Default: no-op. Step 3 scripts should override this.
    }
}

