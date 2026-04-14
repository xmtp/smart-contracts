// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { VmSafe } from "../../lib/forge-std/src/Vm.sol";

/**
 * @title FireblocksNote
 * @notice Utility library for generating Fireblocks transaction notes
 */
library FireblocksNote {
    VmSafe internal constant VM = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @notice Gets or generates a Fireblocks note for transaction tracking
     * @param environment_ The environment name (e.g., "testnet-staging")
     * @param operation_ The operation being performed (e.g., "upgrade", "prepare", "bridge")
     * @param contractName_ The contract name (e.g., "NodeRegistry")
     * @return note_ The Fireblocks note to use
     * @dev If FIREBLOCKS_NOTE env var is set, uses that. Otherwise generates a default note
     *      based on environment, contract name, and operation.
     */
    function getNote(
        string memory environment_,
        string memory operation_,
        string memory contractName_
    ) internal view returns (string memory note_) {
        // Try to read FIREBLOCKS_NOTE env var first
        try VM.envString("FIREBLOCKS_NOTE") returns (string memory envNote_) {
            if (bytes(envNote_).length > 0) {
                return envNote_;
            }
        } catch {}

        return generateNote(environment_, operation_, contractName_);
    }

    /**
     * @notice Always generates a fresh Fireblocks note from parameters, ignoring env vars
     * @param environment_ The environment name (e.g., "testnet-staging")
     * @param operation_ The operation being performed (e.g., "upgrade", "prepare", "bridge")
     * @param contractName_ The contract name (e.g., "NodeRegistry")
     * @return note_ The generated Fireblocks note
     * @dev Use this instead of getNote() when the note must reflect the current contract,
     *      e.g. in DeployImplementationAndMigrator where a stale FIREBLOCKS_NOTE env var
     *      from a previous operation would produce the wrong note.
     */
    function generateNote(
        string memory environment_,
        string memory operation_,
        string memory contractName_
    ) internal pure returns (string memory note_) {
        return string.concat(operation_, " ", contractName_, " on ", environment_);
    }

    /**
     * @notice Tries to read contractName() from a contract address
     * @param contract_ The contract address to query
     * @return name_ The contract name, or empty string if not available
     * @dev Uses staticcall to safely read contractName() from the contract
     */
    function tryGetContractName(address contract_) internal view returns (string memory name_) {
        // Use a minimal interface to call contractName()
        (bool success, bytes memory data) = contract_.staticcall(abi.encodeWithSignature("contractName()"));
        if (success && data.length > 0) {
            return abi.decode(data, (string));
        }
        return "";
    }

    /**
     * @notice Gets the contract name, trying to read from proxy first, then falling back
     * @param proxy_ The proxy contract address
     * @return name_ The contract name
     * @dev Tries to read contractName() from the proxy. Falls back to a default message
     *      if the function doesn't exist (older implementations).
     */
    function getContractName(address proxy_) internal view returns (string memory name_) {
        // Try to read contractName() from the proxy
        string memory contractName_ = tryGetContractName(proxy_);
        if (bytes(contractName_).length > 0) {
            return contractName_;
        }

        // Fallback if contractName() doesn't exist
        return "contractName function not found";
    }
}
