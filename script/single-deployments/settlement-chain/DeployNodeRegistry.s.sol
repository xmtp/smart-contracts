// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../../Deploy.s.sol";
import { NodeRegistryDeployer } from "../../deployers/NodeRegistryDeployer.sol";
import { Utils } from "../../utils/Utils.sol";
import { AdminAddressTypeLib } from "../../utils/AdminAddressType.sol";
import { INodeRegistry } from "../../../src/settlement-chain/interfaces/INodeRegistry.sol";

/**
 * @title DeployNodeRegistryScript
 * @notice Script to deploy a fresh release of the NodeRegistry contract (proxy and implementation pair)
 * @dev This script inherits from Deploy.s.sol, and has four entry points:
 * 
 * 1) deployContract() to deploy a new NodeRegistry contract (proxy and implementation pair)
 * Calls into mass deploy script Deploy.s.sol for a single deployment of NodeRegistry:
 * - Validates the proxy & implementation addresses match the deterministic address held in config JSON.
 * - Deploys the implementation & proxy (no-ops if already present on chain as was requested).
 * - Updates the environment JSON with the new nodeRegistry proxy address.
 * Usage: ENVIRONMENT=testnet-dev forge script DeployNodeRegistryScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
 *
 * 2) SetParameterRegistryValues() to set parameters in the parameter registry (requires ADMIN)
 * Sets the admin and maxCanonicalNodes parameters in the SettlementChainParameterRegistry.
 * For Fireblocks: wrap with `npx fireblocks-json-rpc --http --`
 * Usage (Wallet): ENVIRONMENT=testnet-dev forge script DeployNodeRegistryScript --rpc-url base_sepolia --slow --sig "SetParameterRegistryValues()" --broadcast
 * Usage (Fireblocks): ENVIRONMENT=testnet ADMIN_ADDRESS_TYPE=FIREBLOCKS npx fireblocks-json-rpc --http -- forge script DeployNodeRegistryScript --sender $ADMIN --slow --unlocked --rpc-url {} --sig "SetParameterRegistryValues()" --broadcast
 *
 * 3) UpdateContractDependencies() to update the dependencies of the NodeRegistry contract (uses DEPLOYER, permissionless)
 * Updates the admin and maxCanonicalNodes by calling updateAdmin() and updateMaxCanonicalNodes()
 * Usage: ENVIRONMENT=testnet-dev forge script DeployNodeRegistryScript --rpc-url base_sepolia --slow --sig "UpdateContractDependencies()" --broadcast
 *
 * 4) predictAddresses() to print the predicted addresses of the implementation & proxy (a helper function, doesn't broadcast)
 * The proxy address depends on the factory addresss, deployer address and the salt.
 * The implementation address depends on the factory address and the implementation bytecode.
 * Usage: ENVIRONMENT=testnet-dev forge script DeployNodeRegistryScript --rpc-url base_sepolia --sig "predictAddresses()"
 */
contract DeployNodeRegistryScript is DeployScripts {
    error EnvironmentContainsNodeRegistry();
    error ImplementationAddressMismatch(address expected, address computed);
    error AdminNotSet();

    uint256 internal _adminPrivateKey;
    address internal _admin;
    AdminAddressTypeLib.AdminAddressType internal _adminAddressType;

    /**
     * @dev Initializes admin-related variables. Called at the start of functions that need admin access.
     *      The parent DeployScripts.setUp() already initializes _environment, _deployer, and _deployerPrivateKey.
     */
    function _initializeAdmin() internal {
        // Determine admin address type based on environment with optional override
        _adminAddressType = AdminAddressTypeLib.getAdminAddressType(_environment);

        // Admin setup (for setting parameters in parameter registry)
        if (_adminAddressType == AdminAddressTypeLib.AdminAddressType.Wallet) {
            _adminPrivateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
            if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
            _admin = vm.addr(_adminPrivateKey);
            console.log("Admin (Wallet): %s", _admin);
        } else {
            _admin = vm.envAddress("ADMIN");
            if (_admin == address(0)) revert AdminNotSet();
            console.log("Admin (Fireblocks): %s", _admin);
        }
    }

    function deployContract() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        console.log("Deploying NodeRegistry");

        // Validate config address matches deterministic address before attempting deployment
        _validateImplementationAddress();

        // Deploy implementation first
        deployNodeRegistryImplementation();

        // Deploy proxy (automatically initializes and configures proxy to point at implementation)
        deployNodeRegistryProxy();

        // Update environment JSON with nodeRegistry address
        _writeNodeRegistryToEnvironment();

        console.log("NodeRegistry deployment complete");
    }

    /**
     * @notice Step 2: Set parameter registry values (requires ADMIN)
     * @dev This function is intentionally empty for NodeRegistry because it has no parameters to set.
     *      The admin and maxCanonicalNodes values should be set in the parameter registry manually
     *      before calling UpdateContractDependencies().
     *      This function exists to maintain consistency with other deployment scripts.
     */
    function SetParameterRegistryValues() external {
        _initializeAdmin();
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();

        console.log("NodeRegistry has no parameter registry values to set.");
        console.log("Ensure the following parameters are set manually:");
        console.log("  - xmtp.nodeRegistry.admin");
        console.log("  - xmtp.nodeRegistry.maxCanonicalNodes");
        console.log("Then proceed to UpdateContractDependencies()");
    }

    /**
     * @notice Step 3: Update contract dependencies (permissionless, uses DEPLOYER)
     * @dev Calls updateAdmin() and updateMaxCanonicalNodes() which are permissionless functions
     *      that read from the parameter registry and update local contract state.
     */
    function UpdateContractDependencies() external {
        if (block.chainid != _deploymentData.settlementChainId) revert UnexpectedChainId();
        if (_deploymentData.nodeRegistryProxy == address(0)) revert NodeRegistryProxyNotSet();

        console.log("Updating NodeRegistry dependencies");

        vm.startBroadcast(_deployerPrivateKey);
        INodeRegistry(_deploymentData.nodeRegistryProxy).updateAdmin();
        INodeRegistry(_deploymentData.nodeRegistryProxy).updateMaxCanonicalNodes();
        vm.stopBroadcast();

        // Check if the updated values are zero and log warnings
        address admin_ = INodeRegistry(_deploymentData.nodeRegistryProxy).admin();
        uint8 maxCanonicalNodes_ = INodeRegistry(_deploymentData.nodeRegistryProxy).maxCanonicalNodes();

        if (admin_ == address(0)) {
            console.log("WARNING: NodeRegistry admin is zero address! Set a value in the parameter registry first.");
        }

        if (maxCanonicalNodes_ == 0) {
            console.log(
                "WARNING: NodeRegistry maxCanonicalNodes is zero! Set a value in the parameter registry first."
            );
        }

        console.log("NodeRegistry dependencies updated");
    }

    function predictAddresses() external view {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();
        if (_deploymentData.nodeRegistryProxySalt == 0) revert ProxySaltNotSet();

        address computedImplementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        address computedProxy_ = NodeRegistryDeployer.getProxy(
            _deploymentData.factory,
            _deployer,
            _deploymentData.nodeRegistryProxySalt
        );

        console.log("Proxy Salt:", Utils.bytes32ToString(_deploymentData.nodeRegistryProxySalt));
        console.log("Proxy:", _deploymentData.nodeRegistryProxy);
        console.log("NodeRegistry Predicted Addresses:");
        console.log("  Implementation:", computedImplementation_);
        console.log("  Proxy:", computedProxy_);
        if (_deploymentData.nodeRegistryProxy != address(0)) {
            if (computedProxy_ != _deploymentData.nodeRegistryProxy) {
                console.log("WARNING: Computed proxy address does not match config proxy address!");
            }
        }

        // Check if code already exists at predicted addresses
        if (computedImplementation_.code.length > 0) {
            console.log("WARNING: Code already exists at predicted implementation address!");
        }
        if (computedProxy_.code.length > 0) {
            console.log("WARNING: Code already exists at predicted proxy address!");
        }
    }

    function _ensureNoNodeRegistry(string memory json_) internal view {
        // Copying the intent from Deploy.s.sol. Environment JSON must have any existing node registry value
        // manually removed before starting.
        if (vm.keyExists(json_, ".nodeRegistry")) {
            revert EnvironmentContainsNodeRegistry();
        }
    }

    function _validateImplementationAddress() internal view {
        if (_deploymentData.nodeRegistryImplementation == address(0)) revert ImplementationNotSet();
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        // Compute the deterministic address that will be deployed
        address computedImplementation_ = NodeRegistryDeployer.getImplementation(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        // Validate config address matches deterministic address before attempting deployment
        if (_deploymentData.nodeRegistryImplementation != computedImplementation_) {
            revert ImplementationAddressMismatch(_deploymentData.nodeRegistryImplementation, computedImplementation_);
        }
    }

    function _writeNodeRegistryToEnvironment() internal {
        _prepareEnvironmentJson(_ensureNoNodeRegistry);

        string memory filePath_ = string.concat("environments/", _environment, ".json");

        vm.serializeJson("root", vm.readFile(filePath_));
        string memory json_ = vm.serializeAddress("root", "nodeRegistry", _deploymentData.nodeRegistryProxy);

        // Only update the environment JSON if broadcasting
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            vm.writeJson(json_, filePath_);
        } else {
            console.log("Not broadcasted. No writes to environment JSON.");
        }
    }
}
