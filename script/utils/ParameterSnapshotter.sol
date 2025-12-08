// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";
import { Formatting } from "./Formatting.sol";
import { VmSafe } from "../../lib/forge-std/src/Vm.sol";

/**
 * @title  Parameter Snapshotter Utility
 * @notice Provides reusable functions for querying and formatting parameter registry values
 * @dev    This utility encapsulates all parameter-related logic for clean separation of concerns
 */
library ParameterSnapshotter {
    /**
     * @notice Returns all known parameter keys from both settlement and app chain contracts
     * @return keys_ Array of all known parameter keys
     */
    function getAllKnownKeys() internal pure returns (string[] memory keys_) {
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
    function sortKeys(string[] memory keys_) internal pure {
        uint256 n = keys_.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (compareStrings(keys_[j], keys_[j + 1]) > 0) {
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
    function compareStrings(string memory a_, string memory b_) internal pure returns (int256 result_) {
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
     * @notice Queries parameter values from the parameter registry
     * @param parameterRegistry_ The parameter registry contract
     * @param keys_ Array of parameter keys to query
     * @return values_ Array of parameter values corresponding to the keys
     */
    function queryParameterValues(
        IParameterRegistry parameterRegistry_,
        string[] memory keys_
    ) internal view returns (bytes32[] memory values_) {
        if (address(parameterRegistry_) == address(0)) {
            values_ = new bytes32[](keys_.length);
            return values_;
        }

        // Try batch get first
        try parameterRegistry_.get(keys_) returns (bytes32[] memory vals) {
            return vals;
        } catch {
            // If batch get fails, query individually
            values_ = new bytes32[](keys_.length);
            for (uint256 i = 0; i < keys_.length; i++) {
                try parameterRegistry_.get(keys_[i]) returns (bytes32 val) {
                    values_[i] = val;
                } catch {
                    values_[i] = bytes32(0);
                }
            }
        }
    }

    /**
     * @notice Formats a bytes32 value based on the key type
     * @param vm_ The Vm instance for string conversion
     * @param key_ The parameter key
     * @param value_ The bytes32 value
     * @return formatted_ Formatted string representation of the value
     */
    function formatValue(
        VmSafe vm_,
        string memory key_,
        bytes32 value_
    ) internal view returns (string memory formatted_) {
        if (value_ == bytes32(0)) {
            return "0x0 (not set)";
        }

        // Check if it's a boolean parameter
        if (isBoolKey(key_)) {
            uint256 boolVal = uint256(value_);
            if (boolVal > 1) {
                return string.concat(vm_.toString(value_), " (invalid bool)");
            }
            return boolVal == 0 ? "false" : "true";
        }

        // Check if it's an address parameter
        if (isAddressKey(key_) || isMigratorKey(key_)) {
            address addr = address(uint160(uint256(value_)));
            if (addr == address(0)) {
                return "0x0 (not set)";
            }
            return vm_.toString(addr);
        }

        // Otherwise, treat as uint - strip leading zeros from hex
        uint256 uintVal = uint256(value_);
        string memory hexStr = Formatting.stripLeadingZeros(vm_.toString(value_));
        return string.concat(hexStr, " (", vm_.toString(uintVal), ")");
    }

    /**
     * @notice Formats a bytes32 value as JSON for snapshot output
     * @param vm_ The Vm instance for string conversion
     * @param key_ The parameter key
     * @param value_ The bytes32 value
     * @return json_ JSON-formatted string with key and formatted value
     */
    function formatValueAsJson(
        VmSafe vm_,
        string memory key_,
        bytes32 value_
    ) internal view returns (string memory json_) {
        // Determine the JSON value type based on the key type
        if (isBoolKey(key_)) {
            // Boolean values are already formatted as "true" or "false"
            if (value_ == bytes32(0)) {
                return string.concat('        "', key_, '": null');
            }
            uint256 boolVal = uint256(value_);
            return string.concat('        "', key_, '": ', boolVal == 0 ? "false" : "true");
        } else if (isAddressKey(key_) || isMigratorKey(key_)) {
            // Address values - output as string
            address addr = address(uint160(uint256(value_)));
            if (addr == address(0)) {
                return string.concat('        "', key_, '": null');
            }
            return string.concat('        "', key_, '": "', vm_.toString(addr), '"');
        } else {
            // Uint values - output as number
            if (value_ == bytes32(0)) {
                return string.concat('        "', key_, '": null');
            }
            uint256 uintVal = uint256(value_);
            return string.concat('        "', key_, '": ', vm_.toString(uintVal));
        }
    }

    /**
     * @notice Checks if a key represents a boolean parameter
     */
    function isBoolKey(string memory key_) internal pure returns (bool) {
        return Formatting.endsWith(key_, ".paused");
    }

    /**
     * @notice Checks if a key represents an address parameter
     */
    function isAddressKey(string memory key_) internal pure returns (bool) {
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
    function isMigratorKey(string memory key_) internal pure returns (bool) {
        return Formatting.endsWith(key_, ".migrator");
    }
}
