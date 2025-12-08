// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../lib/forge-std/src/Script.sol";
import { stdJson } from "../lib/forge-std/src/StdJson.sol";
import { IParameterRegistry } from "../src/abstract/interfaces/IParameterRegistry.sol";
import { RegistryParameters } from "../src/libraries/RegistryParameters.sol";
import { Formatting } from "./utils/Formatting.sol";

/**
 * @title  Script to list all known parameter keys and their values
 * @notice This script extracts all known parameter keys from both settlement chain
 *         and app chain contracts, based on static code analysis, and queries their
 *         current values from the appropriate parameter registry.
 * @dev    Run with: forge script script/ListParameterKeys.s.sol:ListParameterKeys --sig "run(string)" <environment> --rpc-url <rpc-url>
 *         Example: forge script script/ListParameterKeys.s.sol:ListParameterKeys --sig "run(string)" testnet-dev --rpc-url base_sepolia
 */
contract ListParameterKeys is Script {
    function run(string memory environment_) external {
        // Read config to determine chain type
        string memory configPath = string.concat("./config/", environment_, ".json");
        string memory json_ = vm.readFile(configPath);

        uint256 settlementChainId = stdJson.readUint(json_, ".settlementChainId");
        uint256 appChainId = stdJson.readUint(json_, ".appChainId");

        // Get current chain ID from RPC
        uint256 currentChainId = block.chainid;

        bool isSettlementChain = (currentChainId == settlementChainId);
        bool isAppChain = (currentChainId == appChainId);

        string memory chainType = "Unknown";
        if (isSettlementChain) {
            chainType = "Settlement Chain";
        } else if (isAppChain) {
            chainType = "App Chain";
        }

        // Get parameter registry address based on chain type
        // Both settlement and app chain use the same config key for now
        address parameterRegistryAddress = stdJson.readAddress(json_, ".parameterRegistryProxy");

        IParameterRegistry parameterRegistry = IParameterRegistry(parameterRegistryAddress);

        console.log("Environment: %s", environment_);
        console.log("Current Chain ID: %d", currentChainId);
        console.log("Settlement Chain ID: %d", settlementChainId);
        console.log("App Chain ID: %d", appChainId);
        console.log("Chain Type: %s", chainType);
        console.log("Parameter Registry: %s", vm.toString(parameterRegistryAddress));
        console.log("");
        console.log("=== PARAMETER KEYS AND VALUES ===");        
        console.log("");

        // Get all known keys (union of both chains)
        string[] memory allKeys = _getAllKnownKeys();

        // Sort keys for better readability
        _sortKeys(allKeys);

        // Query values from parameter registry
        bytes32[] memory values;
        if (parameterRegistryAddress != address(0)) {
            try parameterRegistry.get(allKeys) returns (bytes32[] memory vals) {
                values = vals;
            } catch {
                // If batch get fails, query individually
                values = new bytes32[](allKeys.length);
                for (uint256 i = 0; i < allKeys.length; i++) {
                    try parameterRegistry.get(allKeys[i]) returns (bytes32 val) {
                        values[i] = val;
                    } catch {
                        values[i] = bytes32(0);
                    }
                }
            }
        } else {
            values = new bytes32[](allKeys.length);
        }

        // Print all keys with their values
        for (uint256 i = 0; i < allKeys.length; i++) {
            string memory valueStr = _formatValue(allKeys[i], values[i]);
            console.log("%s = %s", allKeys[i], valueStr);
        }

        console.log("");
        console.log("Total known keys: %d", allKeys.length);
        console.log("");
        console.log("Excluded dynamic keys:");
        console.log("  - xmtp.appChainParameterRegistry.isAdmin.{address}");
        console.log("  - xmtp.settlementChainGateway.inbox.{chainId}");
        console.log("  - xmtp.settlementChainParameterRegistry.isAdmin.{address}");
    }

    /**
     * @notice Returns all known parameter keys from both settlement and app chain contracts
     * @return keys_ Array of all known parameter keys
     */
    function _getAllKnownKeys() internal pure returns (string[] memory keys_) {
        // Count total keys
        uint256 count = 0;

        // Settlement Chain keys
        count += 1; // settlementChainParameterRegistry.migrator
        count += 1; // feeToken.migrator
        count += 3; // nodeRegistry (admin, maxCanonicalNodes, migrator)
        count += 6; // payerRegistry (settler, feeDistributor, minimumDeposit, withdrawLockPeriod, paused, migrator)
        count += 2; // payerReportManager (migrator, protocolFeeRate)
        count += 3; // distributionManager (migrator, paused, protocolFeesRecipient)
        count += 5; // rateRegistry (messageFee, storageFee, congestionFee, targetRatePerMinute, migrator)
        count += 2; // settlementChainGateway (migrator, paused)
        count += 2; // factory (paused, migrator)

        // App Chain keys
        count += 1; // appChainParameterRegistry.migrator
        count += 2; // appChainGateway (migrator, paused)
        count += 5; // groupMessageBroadcaster (minPayloadSize, maxPayloadSize, migrator, paused, payloadBootstrapper)
        count += 5; // identityUpdateBroadcaster (minPayloadSize, maxPayloadSize, migrator, paused, payloadBootstrapper)

        keys_ = new string[](count);
        uint256 index = 0;

        // Settlement Chain Parameter Registry
        keys_[index++] = "xmtp.settlementChainParameterRegistry.migrator";

        // Fee Token
        keys_[index++] = "xmtp.feeToken.migrator";

        // Node Registry
        keys_[index++] = "xmtp.nodeRegistry.admin";
        keys_[index++] = "xmtp.nodeRegistry.maxCanonicalNodes";
        keys_[index++] = "xmtp.nodeRegistry.migrator";

        // Payer Registry
        keys_[index++] = "xmtp.payerRegistry.settler";
        keys_[index++] = "xmtp.payerRegistry.feeDistributor";
        keys_[index++] = "xmtp.payerRegistry.minimumDeposit";
        keys_[index++] = "xmtp.payerRegistry.withdrawLockPeriod";
        keys_[index++] = "xmtp.payerRegistry.paused";
        keys_[index++] = "xmtp.payerRegistry.migrator";

        // Payer Report Manager
        keys_[index++] = "xmtp.payerReportManager.migrator";
        keys_[index++] = "xmtp.payerReportManager.protocolFeeRate";

        // Distribution Manager
        keys_[index++] = "xmtp.distributionManager.migrator";
        keys_[index++] = "xmtp.distributionManager.paused";
        keys_[index++] = "xmtp.distributionManager.protocolFeesRecipient";

        // Rate Registry
        keys_[index++] = "xmtp.rateRegistry.messageFee";
        keys_[index++] = "xmtp.rateRegistry.storageFee";
        keys_[index++] = "xmtp.rateRegistry.congestionFee";
        keys_[index++] = "xmtp.rateRegistry.targetRatePerMinute";
        keys_[index++] = "xmtp.rateRegistry.migrator";

        // Settlement Chain Gateway
        keys_[index++] = "xmtp.settlementChainGateway.migrator";
        keys_[index++] = "xmtp.settlementChainGateway.paused";

        // Factory
        keys_[index++] = "xmtp.factory.paused";
        keys_[index++] = "xmtp.factory.migrator";

        // App Chain Parameter Registry
        keys_[index++] = "xmtp.appChainParameterRegistry.migrator";

        // App Chain Gateway
        keys_[index++] = "xmtp.appChainGateway.migrator";
        keys_[index++] = "xmtp.appChainGateway.paused";

        // Group Message Broadcaster
        keys_[index++] = "xmtp.groupMessageBroadcaster.minPayloadSize";
        keys_[index++] = "xmtp.groupMessageBroadcaster.maxPayloadSize";
        keys_[index++] = "xmtp.groupMessageBroadcaster.migrator";
        keys_[index++] = "xmtp.groupMessageBroadcaster.paused";
        keys_[index++] = "xmtp.groupMessageBroadcaster.payloadBootstrapper";

        // Identity Update Broadcaster
        keys_[index++] = "xmtp.identityUpdateBroadcaster.minPayloadSize";
        keys_[index++] = "xmtp.identityUpdateBroadcaster.maxPayloadSize";
        keys_[index++] = "xmtp.identityUpdateBroadcaster.migrator";
        keys_[index++] = "xmtp.identityUpdateBroadcaster.paused";
        keys_[index++] = "xmtp.identityUpdateBroadcaster.payloadBootstrapper";
    }

    /**
     * @notice Sorts an array of strings in place using bubble sort
     * @param keys_ Array of keys to sort
     */
    function _sortKeys(string[] memory keys_) internal pure {
        uint256 n = keys_.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (_compareStrings(keys_[j], keys_[j + 1]) > 0) {
                    string memory temp = keys_[j];
                    keys_[j] = keys_[j + 1];
                    keys_[j + 1] = temp;
                }
            }
        }
    }

    /**
     * @notice Compares two strings lexicographically
     * @param a_ First string
     * @param b_ Second string
     * @return result_ Negative if a_ < b_, zero if equal, positive if a_ > b_
     */
    function _compareStrings(string memory a_, string memory b_) internal pure returns (int256 result_) {
        bytes memory aBytes = bytes(a_);
        bytes memory bBytes = bytes(b_);
        uint256 minLength = aBytes.length < bBytes.length ? aBytes.length : bBytes.length;

        for (uint256 i = 0; i < minLength; i++) {
            if (aBytes[i] < bBytes[i]) {
                return -1;
            } else if (aBytes[i] > bBytes[i]) {
                return 1;
            }
        }

        if (aBytes.length < bBytes.length) {
            return -1;
        } else if (aBytes.length > bBytes.length) {
            return 1;
        }

        return 0;
    }

    /**
     * @notice Formats a bytes32 value based on the key type
     * @param key_ The parameter key
     * @param value_ The bytes32 value
     * @return formatted_ Formatted string representation of the value
     */
    function _formatValue(string memory key_, bytes32 value_) internal view returns (string memory formatted_) {
        if (value_ == bytes32(0)) {
            return "0x0 (not set)";
        }

        // Check if it's a boolean parameter
        if (_isBoolKey(key_)) {
            uint256 boolVal = uint256(value_);
            if (boolVal > 1) {
                return string.concat(vm.toString(value_), " (invalid bool)");
            }
            return boolVal == 0 ? "false" : "true";
        }

        // Check if it's an address parameter
        if (_isAddressKey(key_) || _isMigratorKey(key_)) {
            address addr = address(uint160(uint256(value_)));
            if (addr == address(0)) {
                return "0x0 (not set)";
            }
            return vm.toString(addr);
        }

        // Otherwise, treat as uint - strip leading zeros from hex
        uint256 uintVal = uint256(value_);
        string memory hexStr = Formatting.stripLeadingZeros(vm.toString(value_));
        return string.concat(hexStr, " (", vm.toString(uintVal), ")");
    }

    /**
     * @notice Checks if a key represents a boolean parameter
     */
    function _isBoolKey(string memory key_) internal pure returns (bool) {
        return Formatting.endsWith(key_, ".paused");
    }

    /**
     * @notice Checks if a key represents an address parameter
     */
    function _isAddressKey(string memory key_) internal pure returns (bool) {
        return
            Formatting.endsWith(key_, ".admin") ||
            Formatting.endsWith(key_, ".settler") ||
            Formatting.endsWith(key_, ".feeDistributor") ||
            Formatting.endsWith(key_, ".protocolFeesRecipient") ||
            Formatting.endsWith(key_, ".payloadBootstrapper");
    }

    /**
     * @notice Checks if a key represents a migrator parameter (address)
     */
    function _isMigratorKey(string memory key_) internal pure returns (bool) {
        return Formatting.endsWith(key_, ".migrator");
    }
}
