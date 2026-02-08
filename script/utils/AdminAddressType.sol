// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VmSafe } from "../../lib/forge-std/src/Vm.sol";

/**
 * @title AdminAddressType
 * @notice Utility library for determining admin address type based on environment
 * @dev Environment-specific defaults:
 *      - testnet-dev: default WALLET, can override with ADMIN_ADDRESS_TYPE=FIREBLOCKS
 *      - testnet-staging: default WALLET, can override with ADMIN_ADDRESS_TYPE=FIREBLOCKS
 *      - testnet: default FIREBLOCKS, can override with ADMIN_ADDRESS_TYPE=WALLET
 *      - mainnet: always FIREBLOCKS (override ignored)
 */
library AdminAddressTypeLib {
    VmSafe internal constant VM = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    enum AdminAddressType {
        Wallet,
        Fireblocks
    }

    /**
     * @notice Determines admin address type based on environment with optional override
     * @param environment_ The environment name
     * @return adminAddressType_ The admin address type to use
     * @dev Environment-specific defaults:
     *      - testnet-dev: default WALLET, can override with ADMIN_ADDRESS_TYPE=FIREBLOCKS
     *      - testnet-staging: default WALLET, can override with ADMIN_ADDRESS_TYPE=FIREBLOCKS
     *      - testnet: default FIREBLOCKS, can override with ADMIN_ADDRESS_TYPE=WALLET
     *      - mainnet: always FIREBLOCKS (override ignored)
     */
    function getAdminAddressType(
        string memory environment_
    ) internal view returns (AdminAddressType adminAddressType_) {
        // mainnet: always fireblocks (override ignored)
        if (keccak256(bytes(environment_)) == keccak256(bytes("mainnet"))) {
            return AdminAddressType.Fireblocks;
        }

        // Check for explicit override for other environments
        try VM.envString("ADMIN_ADDRESS_TYPE") returns (string memory override_) {
            if (keccak256(bytes(override_)) == keccak256(bytes("FIREBLOCKS"))) {
                return AdminAddressType.Fireblocks;
            } else if (
                keccak256(bytes(override_)) == keccak256(bytes("WALLET")) ||
                keccak256(bytes(override_)) == keccak256(bytes("PRIVATE_KEY"))
            ) {
                return AdminAddressType.Wallet;
            }
        } catch {}

        // Apply environment-specific defaults
        if (keccak256(bytes(environment_)) == keccak256(bytes("testnet-dev"))) {
            return AdminAddressType.Wallet;
        } else if (keccak256(bytes(environment_)) == keccak256(bytes("testnet-staging"))) {
            return AdminAddressType.Wallet;
        } else if (keccak256(bytes(environment_)) == keccak256(bytes("testnet"))) {
            return AdminAddressType.Fireblocks;
        }

        // Default to wallet for unknown environments
        return AdminAddressType.Wallet;
    }
}
