// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Interface defining errors for Sequential Merkle Proofs library.
 * @dev   This interface should be inherited by any contract that uses the Sequential Merkle Proofs library in order to
 *        expose the errors that may be thrown by the library.
 */
interface ISequentialMerkleProofsErrors {
    /// @notice Thrown when no leaves are provided.
    error NoLeaves();

    /// @notice Thrown when the input to _bitCount32 is greater than type(uint32).max.
    error InvalidBitCount32Input();

    /// @notice Thrown when the proof is invalid.
    error InvalidProof();

    /// @notice Thrown when no proof elements are provided.
    error NoProofElements();

    /// @notice Thrown when the leaf count is greater than type(uint32).max.
    error InvalidLeafCount();
}
