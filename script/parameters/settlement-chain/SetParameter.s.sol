// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @title  Set a parameter in the Settlement Chain Parameter Registry
 * @notice Sets a single key-value pair in the SettlementChainParameterRegistry.
 *         The caller must be an admin of the parameter registry.
 * @dev    Admin address type is determined by environment with optional ADMIN_ADDRESS_TYPE override:
 *         - testnet-dev: default PRIVATE_KEY, can override with ADMIN_ADDRESS_TYPE=FIREBLOCKS
 *         - testnet-staging: default PRIVATE_KEY, can override with ADMIN_ADDRESS_TYPE=FIREBLOCKS
 *         - testnet: default FIREBLOCKS, can override with ADMIN_ADDRESS_TYPE=PRIVATE_KEY
 *         - mainnet: always FIREBLOCKS (override ignored, requires ADMIN address)
 */
contract SetParameter is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error AdminNotSet();

    enum AdminAddressType {
        PrivateKey,
        Fireblocks
    }

    string internal _environment;
    uint256 internal _adminPrivateKey;
    address internal _admin;
    AdminAddressType internal _adminAddressType;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Deployment data
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        // Determine admin address type based on environment with optional override
        _adminAddressType = _getAdminAddressType(_environment);

        // Admin setup
        if (_adminAddressType == AdminAddressType.PrivateKey) {
            _adminPrivateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
            if (_adminPrivateKey == 0) revert PrivateKeyNotSet();
            _admin = vm.addr(_adminPrivateKey);
            console.log("Admin (Private Key): %s", _admin);
        } else {
            _admin = vm.envAddress("ADMIN");
            if (_admin == address(0)) revert AdminNotSet();
            console.log("Admin (Fireblocks): %s", _admin);
        }
    }

    /**
     * @notice Determines admin address type based on environment with optional override
     * @param environment_ The environment name
     * @return adminAddressType_ The admin address type to use
     */
    function _getAdminAddressType(
        string memory environment_
    ) internal view returns (AdminAddressType adminAddressType_) {
        // mainnet: always fireblocks (override ignored)
        if (keccak256(bytes(environment_)) == keccak256(bytes("mainnet"))) {
            return AdminAddressType.Fireblocks;
        }

        // Check for explicit override for other environments
        try vm.envString("ADMIN_ADDRESS_TYPE") returns (string memory override_) {
            if (keccak256(bytes(override_)) == keccak256(bytes("FIREBLOCKS"))) {
                return AdminAddressType.Fireblocks;
            } else if (keccak256(bytes(override_)) == keccak256(bytes("PRIVATE_KEY"))) {
                return AdminAddressType.PrivateKey;
            }
        } catch {}

        // Apply environment-specific defaults
        if (keccak256(bytes(environment_)) == keccak256(bytes("testnet-dev"))) {
            return AdminAddressType.PrivateKey;
        } else if (keccak256(bytes(environment_)) == keccak256(bytes("testnet-staging"))) {
            return AdminAddressType.PrivateKey;
        } else if (keccak256(bytes(environment_)) == keccak256(bytes("testnet"))) {
            return AdminAddressType.Fireblocks;
        }

        // Default to private key for unknown environments
        return AdminAddressType.PrivateKey;
    }

    /**
     * @notice Sets a parameter in the settlement chain parameter registry
     * @param key_ The parameter key (e.g., "xmtp.nodeRegistry.admin")
     * @param value_ The parameter value as bytes32
     */
    function set(string calldata key_, bytes32 value_) external {
        address paramRegistry = _deployment.parameterRegistryProxy;

        console.log("Parameter Registry: %s", paramRegistry);
        console.log("Key: %s", key_);
        console.log("Value (bytes32):");
        console.logBytes32(value_);

        if (_adminAddressType == AdminAddressType.PrivateKey) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        IParameterRegistry(paramRegistry).set(key_, value_);
        console.log("Parameter set successfully");

        vm.stopBroadcast();
    }

    /**
     * @notice Sets a parameter with an address value
     * @param key_ The parameter key
     * @param value_ The address value
     */
    function setAddress(string calldata key_, address value_) external {
        address paramRegistry = _deployment.parameterRegistryProxy;

        console.log("Parameter Registry: %s", paramRegistry);
        console.log("Key: %s", key_);
        console.log("Value (address): %s", value_);

        bytes32 encodedValue = Utils.encodeAddress(value_);

        if (_adminAddressType == AdminAddressType.PrivateKey) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        IParameterRegistry(paramRegistry).set(key_, encodedValue);
        console.log("Parameter set successfully");

        vm.stopBroadcast();
    }

    /**
     * @notice Sets a parameter with a uint256 value
     * @param key_ The parameter key
     * @param value_ The uint256 value
     */
    function setUint(string calldata key_, uint256 value_) external {
        address paramRegistry = _deployment.parameterRegistryProxy;

        console.log("Parameter Registry: %s", paramRegistry);
        console.log("Key: %s", key_);
        console.log("Value (uint256): %s", value_);

        bytes32 encodedValue = Utils.encodeUint(value_);

        if (_adminAddressType == AdminAddressType.PrivateKey) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        IParameterRegistry(paramRegistry).set(key_, encodedValue);
        console.log("Parameter set successfully");

        vm.stopBroadcast();
    }

    /**
     * @notice Sets a parameter with a boolean value
     * @param key_ The parameter key
     * @param value_ The boolean value
     */
    function setBool(string calldata key_, bool value_) external {
        address paramRegistry = _deployment.parameterRegistryProxy;

        console.log("Parameter Registry: %s", paramRegistry);
        console.log("Key: %s", key_);
        console.log("Value (bool): %s", value_);

        bytes32 encodedValue = Utils.encodeBool(value_);

        if (_adminAddressType == AdminAddressType.PrivateKey) {
            vm.startBroadcast(_adminPrivateKey);
        } else {
            vm.startBroadcast(_admin);
        }

        IParameterRegistry(paramRegistry).set(key_, encodedValue);
        console.log("Parameter set successfully");

        vm.stopBroadcast();
    }

    /**
     * @notice Gets the current value of a parameter
     * @param key_ The parameter key
     */
    function get(string calldata key_) external view {
        address paramRegistry = _deployment.parameterRegistryProxy;

        console.log("Parameter Registry: %s", paramRegistry);
        console.log("Key: %s", key_);

        bytes32 value = IParameterRegistry(paramRegistry).get(key_);
        console.log("Value (bytes32):");
        console.logBytes32(value);
        console.log("Value (uint256): %s", uint256(value));
        console.log("Value (address): %s", address(uint160(uint256(value))));
    }
}
