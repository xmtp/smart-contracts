// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ISequentialMerkleProofsErrors } from "./interfaces/ISequentialMerkleProofsErrors.sol";

/**
 * @title  Library for verifying sequential merkle proofs.
 * @notice A sequential merkle proof is a proof that leaves appear sequentially in a merkle tree.
 */
library SequentialMerkleProofs {
    /* ============ Constants ============ */

    bytes32 internal constant EMPTY_TREE_ROOT = 0;

    /// @notice The leaf prefix used to hash to a leaf ("leaf|").
    bytes5 internal constant LEAF_PREFIX = 0x6c6561667c;

    /// @notice The node prefix used to hash to a node ("node|").
    bytes5 internal constant NODE_PREFIX = 0x6e6f64657c;

    /// @notice The root prefix used to hash to a root.
    bytes5 internal constant ROOT_PREFIX = 0x726f6f747c;

    /* ============ Main Functions ============ */

    /**
     * @notice Verifies a sequential merkle proof.
     * @param  root_          The root of the merkle tree.
     * @param  startingIndex_ The index of the first leaf provided.
     * @param  leaves_        The leaves to prove sequential existence from the starting index.
     * @param  proofElements_ The merkle proof data.
     * @dev    proofElements_[0] is the total number of leaves in the merkle tree, the rest are the decommitments.
     * @dev    Can also revert with an array out-of-bounds access panic.
     */
    function verify(
        bytes32 root_,
        uint256 startingIndex_,
        bytes[] calldata leaves_,
        bytes32[] calldata proofElements_
    ) internal pure {
        if (getRoot(startingIndex_, leaves_, proofElements_) != root_) {
            revert ISequentialMerkleProofsErrors.InvalidProof();
        }
    }

    /**
     * @notice Gets the root of a sequential merkle proof.
     * @param  startingIndex_ The index of the first leaf provided.
     * @param  leaves_        The leaves to prove sequential existence from the starting index.
     * @param  proofElements_ The merkle proof data.
     * @dev    proofElements_[0] is the total number of leaves in the merkle tree, the rest are the decommitments.
     * @dev    Can also revert with an array out-of-bounds access panic.
     */
    function getRoot(
        uint256 startingIndex_,
        bytes[] calldata leaves_,
        bytes32[] calldata proofElements_
    ) internal pure returns (bytes32 root_) {
        return _getRoot(startingIndex_, _getReversedLeafNodesFromLeaves(leaves_), proofElements_);
    }

    /**
     * @notice Extracts the leaf count from a sequential merkle proof, without verifying the proof.
     * @param  proofElements_ The merkle proof data.
     * @dev    proofElements_[0] is the total number of leaves in the merkle tree.
     * @dev    Does not verify the proof. Only extracts the leaf count from the proof elements.
     */
    function getLeafCount(bytes32[] calldata proofElements_) internal pure returns (uint32 leafCount_) {
        if (proofElements_.length == 0) revert ISequentialMerkleProofsErrors.NoProofElements();

        if (uint256(proofElements_[0]) > type(uint32).max) revert ISequentialMerkleProofsErrors.InvalidLeafCount();

        return uint32(uint256(proofElements_[0]));
    }

    /* ============ Helper Functions ============ */

    /**
     * @notice Counts number of set bits (1's) in 32-bit unsigned integer.
     * @dev    See https://en.wikipedia.org/wiki/Hamming_weight implementation `popcount64b`.
     * @param  n_        The number to count the set bits of.
     * @return bitCount_ The number of set bits in `n_`.
     * @dev    Literals are inlined as they are very specific to this algorithm/function, and actually improve
     *         readability, given their patterns.
     */
    function _bitCount32(uint256 n_) internal pure returns (uint256 bitCount_) {
        if (n_ > type(uint32).max) revert ISequentialMerkleProofsErrors.InvalidBitCount32Input();

        unchecked {
            n_ -= (n_ >> 1) & 0x55555555;
            n_ = (n_ & 0x33333333) + ((n_ >> 2) & 0x33333333);
            n_ = (n_ + (n_ >> 4)) & 0x0f0f0f0f;
            n_ += n_ >> 8;
            n_ += n_ >> 16;

            return n_ & 0x7f;
        }
    }

    /**
     * @notice Rounds a 32-bit unsigned integer up to the nearest power of 2.
     * @param  n_        The number to round up to the nearest power of 2.
     * @return powerOf2_ The nearest power of 2 to `n_`.
     * @dev    Literals are inlined as they are very specific to this algorithm/function, and actually improve
     *         readability, given their patterns.
     */
    function _roundUpToPowerOf2(uint256 n_) internal pure returns (uint256 powerOf2_) {
        if (_bitCount32(n_) == 1) return n_;

        unchecked {
            n_ |= n_ >> 1;
            n_ |= n_ >> 2;
            n_ |= n_ >> 4;
            n_ |= n_ >> 8;
            n_ |= n_ >> 16;

            return n_ + 1;
        }
    }

    /**
     * @notice Gets the balanced leaf count for a sequential merkle proof.
     * @param  leafCount_         The number of leaves in the merkle tree.
     * @return balancedLeafCount_ The balanced leaf count.
     */
    function _getBalancedLeafCount(uint256 leafCount_) internal pure returns (uint256 balancedLeafCount_) {
        return leafCount_ <= 1 ? (leafCount_ * 2) : _roundUpToPowerOf2(leafCount_);
    }

    /**
     * @notice Gets the root of a sequential merkle proof.
     * @param  startingIndex_ The index of the first leaf provided.
     * @param  hashes_        The leaf hashes (in reverse order) to prove sequential existence from the starting index.
     * @param  proofElements_         The merkle proof data.
     * @dev    proofElements_[0] is the total number of leaves in the merkle tree, the rest are the decommitments.
     */
    function _getRoot(
        uint256 startingIndex_,
        bytes32[] memory hashes_,
        bytes32[] calldata proofElements_
    ) internal pure returns (bytes32 root_) {
        if (proofElements_.length == 0) revert ISequentialMerkleProofsErrors.NoProofElements();

        if (startingIndex_ == 0 && hashes_.length == 0 && uint256(proofElements_[0]) == 0) return EMPTY_TREE_ROOT;

        if (hashes_.length == 0) revert ISequentialMerkleProofsErrors.NoLeaves();

        if (startingIndex_ + hashes_.length > uint256(proofElements_[0])) {
            revert ISequentialMerkleProofsErrors.InvalidProof();
        }

        uint256 count_ = hashes_.length;
        uint256[] memory treeIndices_ = new uint256[](count_);

        /**
         * @dev The following variables are used while iterating through the root reconstruction from the proof.
         * @dev `readIndex_` is the index of `hashes_` circular queue currently being read from.
         * @dev `writeIndex_` is the index of `hashes_` circular queue currently being written to.
         * @dev `proofIndex_` is the index of `proofElements_` array that is to be read from.
         * @dev `upperBound_` is the rightmost tree index, of the current level of the tree, such that all nodes to the
         *         right, if any, are non-existent.
         * @dev `lowestTreeIndex_` is the tree index, of the current level of the tree, of the leftmost node we have.
         * @dev `highestLeafNodeIndex_` is the tree index of the rightmost leaf node we have.
         */
        uint256 readIndex_ = 0;
        uint256 writeIndex_ = 0;
        uint256 proofIndex_ = 1; // proofElements_[0] is the total leaf count, and is already consumed.
        uint256 upperBound_ = _getBalancedLeafCount(uint256(proofElements_[0])) + uint256(proofElements_[0]) - 1;
        uint256 lowestTreeIndex_ = _getBalancedLeafCount(uint256(proofElements_[0])) + startingIndex_;
        uint256 highestLeafNodeIndex_ = lowestTreeIndex_ + count_ - 1;

        while (true) {
            /// @dev `nodeIndex_` is the tree index of the current node we are handling.
            // Instead of doing a full pass through the empty tree indices array to build a starting sequential set of
            // indices, we can just check if we are in that "first pass" by checking if `readIndex_ < count_`, and if so
            // compute the index as needed given the `highestLeafNodeIndex_` and the `readIndex_`.
            uint256 nodeIndex_ = readIndex_ < count_
                ? highestLeafNodeIndex_ - readIndex_
                : treeIndices_[readIndex_ % count_];

            // If we reach the sub-root (i.e. `nodeIndex_ == 1`), we can return the root (i.e. `nodeIndex_ == 0`) by
            // hashing the tree's leaf count with the last computed hash.
            if (nodeIndex_ == 1) return _hashRoot(uint256(proofElements_[0]), hashes_[(writeIndex_ - 1) % count_]);

            // If node index we are handling is the upper bound and is even, then it's sibling to the right does not
            // exist (since this is an unbalanced tree), so we can just copy the hash up one level.
            if ((nodeIndex_ == upperBound_) && _isEven(nodeIndex_)) {
                hashes_[writeIndex_ % count_] = _hashPairlessNode(hashes_[readIndex_ % count_]);
                treeIndices_[writeIndex_ % count_] = nodeIndex_ >> 1;

                unchecked {
                    ++readIndex_;
                    ++writeIndex_;
                }

                // If we are not at the lowest tree index (i.e. there are nodes to the left that we have yet to process
                // at this level), then continue.
                if (nodeIndex_ != lowestTreeIndex_) continue;

                // If we are at the lowest tree index (i.e. there are no nodes to the left that we have yet to process
                // at this level), then we can update the lower bound and upper bound for the next level up.
                lowestTreeIndex_ >>= 1;
                upperBound_ >>= 1;

                continue;
            }

            /// @dev `nextNodeIndex_` is the tree index of the next node we may be handling.
            // Instead of doing a full pass through the empty tree indices array to build a starting sequential set of
            // indices, we can just check if we are in that "first pass" by checking if `readIndex_ + 1 < count_`, and
            // if so compute the next index as needed given the `highestLeafNodeIndex_` and the `readIndex_`.
            uint256 nextNodeIndex_ = (readIndex_ + 1) < count_
                ? highestLeafNodeIndex_ - (readIndex_ + 1)
                : treeIndices_[(readIndex_ + 1) % count_];

            /// @dev `root_` will temporarily be used as the right part of the node pair hash, it is being used to
            ///      save much needed stack space.
            // Since we are processing nodes from right to left, then if the current node index is even, and there
            // exists nodes to the right (or else the previous if-continue would have been hit), then the right part of
            // the hash is a decommitment. If the current node index is odd, then the right part of the hash we already
            // have computed.
            unchecked {
                root_ = _isEven(nodeIndex_) ? proofElements_[proofIndex_++] : hashes_[readIndex_++ % count_];
            }

            /// @dev `left_` is the left part of the node pair hash.
            bytes32 left_;

            // Based on the current node index and the next node index, we can determine if the left part of the hash
            // is an existing computed hash or a decommitment.
            unchecked {
                left_ = _isLeftAnExistingHash(nodeIndex_, nextNodeIndex_)
                    ? hashes_[readIndex_++ % count_]
                    : proofElements_[proofIndex_++];
            }

            hashes_[writeIndex_ % count_] = _hashNodePair(left_, root_);
            treeIndices_[writeIndex_ % count_] = nodeIndex_ >> 1;

            unchecked {
                ++writeIndex_;
            }

            // If we are not at the lowest tree index (i.e. there are nodes to the left that we have yet to process
            // at this level), then continue.
            // NOTE: Technically, if only `nextNodeIndex_ == lowestTreeIndex_`, and we did not use the hash at that
            // `nextNodeIndex_` as part of this step's hashing, then it was a node not yet handled, but it will be
            // handled in the next iteration, so the process will continue normally even if we prematurely "leveled up".
            if (nodeIndex_ != lowestTreeIndex_ && nextNodeIndex_ != lowestTreeIndex_) continue;

            // If we are at the lowest tree index (i.e. there are no nodes to the left that we have yet to process
            // at this level), then we can update the lower bound and upper bound for the next level up.
            // NOTE: Again, see the NOTE above.
            lowestTreeIndex_ >>= 1;
            upperBound_ >>= 1;
        }
    }

    function _isEven(uint256 n_) internal pure returns (bool isEven_) {
        return (n_ & 1) == 0;
    }

    /**
     * @notice Checks if the left part of the hash should be an existing computed hash.
     * @param  nodeIndex_            The index of the current node in the tree indices array.
     * @param  nextNodeIndex_        The index of the next (lower) node in the tree indices array.
     * @return isLeftAnExistingHash_ True if the left part of the hash should be an existing computed hash.
     */
    function _isLeftAnExistingHash(
        uint256 nodeIndex_,
        uint256 nextNodeIndex_
    ) internal pure returns (bool isLeftAnExistingHash_) {
        unchecked {
            return _isEven(nodeIndex_) || (nextNodeIndex_ == nodeIndex_ - 1);
        }
    }

    /**
     * @notice Hashes a leaf of arbitrary size into a 32-byte leaf node.
     * @param  leaf_ The leaf to hash.
     * @return hash_ The hash of the leaf.
     */
    function _hashLeaf(bytes calldata leaf_) internal pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(LEAF_PREFIX, leaf_));
    }

    /**
     * @notice Hashes a pair of 32-byte nodes into a 32-byte parent node.
     * @param  leftNode_  The left node to hash.
     * @param  rightNode_ The right node to hash.
     * @return hash_      The hash of the pair of nodes.
     */
    function _hashNodePair(bytes32 leftNode_, bytes32 rightNode_) internal pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(NODE_PREFIX, leftNode_, rightNode_));
    }

    /**
     * @notice Hashes a 32-byte node, without a right paired node, into a 32-byte parent node.
     * @param  node_ The node to hash.
     * @return hash_ The hash of the node.
     */
    function _hashPairlessNode(bytes32 node_) internal pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(NODE_PREFIX, node_));
    }

    /**
     * @notice Hashes the topmost 32-byte node in the tree, combined with the tree's leaf count, into a 32-byte root.
     * @param  leafCount_ The number of leaves in the merkle tree.
     * @param  node_      The topmost node in the tree.
     * @return hash_      The root hash of the tree.
     */
    function _hashRoot(uint256 leafCount_, bytes32 node_) internal pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(ROOT_PREFIX, leafCount_, node_));
    }

    /// @notice Get leaf nodes from arbitrary size leaves in calldata, in reverse order.
    function _getReversedLeafNodesFromLeaves(
        bytes[] calldata leaves_
    ) internal pure returns (bytes32[] memory leafNodes_) {
        uint256 count_ = leaves_.length;
        leafNodes_ = new bytes32[](count_);
        uint256 readIndex_ = count_;
        uint256 writeIndex_;

        while (writeIndex_ < count_) {
            unchecked {
                leafNodes_[writeIndex_++] = _hashLeaf(leaves_[--readIndex_]);
            }
        }
    }
}
