// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  Formatting utilities for scripts
 * @notice Provides string formatting functions for script output
 */
library Formatting {
    /**
     * @notice Checks if a string ends with a suffix
     * @param str_ The string to check
     * @param suffix_ The suffix to look for
     * @return True if the string ends with the suffix, false otherwise
     */
    function endsWith(string memory str_, string memory suffix_) internal pure returns (bool) {
        bytes memory strBytes = bytes(str_);
        bytes memory suffixBytes = bytes(suffix_);

        if (suffixBytes.length > strBytes.length) {
            return false;
        }

        uint256 start = strBytes.length - suffixBytes.length;
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            if (strBytes[start + i] != suffixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Strips leading zeros from a hex string (e.g., "0x00000064" -> "0x64")
     * @param hexStr_ The hex string to process
     * @return stripped_ The hex string with leading zeros removed
     * @dev Returns "0x0" if all digits after "0x" are zeros
     * @dev Returns the original string if it doesn't start with "0x"
     */
    function stripLeadingZeros(string memory hexStr_) internal pure returns (string memory stripped_) {
        bytes memory hexBytes = bytes(hexStr_);

        // Must start with "0x"
        if (hexBytes.length < 3 || hexBytes[0] != 0x30 || hexBytes[1] != 0x78) {
            return hexStr_; // Return as-is if not a valid hex string
        }

        // Find first non-zero character after "0x"
        uint256 firstNonZero = 2;
        while (firstNonZero < hexBytes.length && hexBytes[firstNonZero] == 0x30) {
            firstNonZero++;
        }

        // If all zeros after "0x", return "0x0"
        if (firstNonZero == hexBytes.length) {
            return "0x0";
        }

        // Build result: "0x" + remaining hex digits
        uint256 resultLength = 2 + (hexBytes.length - firstNonZero);
        bytes memory result = new bytes(resultLength);
        result[0] = 0x30; // '0'
        result[1] = 0x78; // 'x'

        for (uint256 i = 0; i < hexBytes.length - firstNonZero; i++) {
            result[i + 2] = hexBytes[firstNonZero + i];
        }

        return string(result);
    }
}

