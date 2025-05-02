// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  Library for verifying sequential merkle proofs.
 * @notice A sequential merkle proof is a proof that leaves appear sequentially in a merkle tree.
 */
library SequentialMerkleProofs {
    /* ============ Constants ============ */

    /// @notice The leaf prefix used to hash to a leaf.
    bytes internal constant LEAF_PREFIX = bytes("leaf|");

    /// @notice The node prefix used to hash to a node.
    bytes internal constant NODE_PREFIX = bytes("node|");

    /// @notice The root prefix used to hash to a root.
    bytes internal constant ROOT_PREFIX = bytes("root|");

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the no leaves are passed.
    error NoLeaves();

    /// @notice Thrown when the input to _roundUpToPowerOf2 is greater than type(uint64).max.
    error InvalidRoundUpToPowerOf2Input();

    /// @notice Thrown when the input to _bitCount64 is greater than type(uint64).max.
    error InvalidBitCount64Input();

    /// @notice Thrown when the proof is invalid.
    error InvalidProof();

    /// @notice Thrown when no proof elements are provided.
    error NoProofElements();

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
        uint256 root_,
        uint256 startingIndex_,
        bytes[] calldata leaves_,
        uint256[] calldata proofElements_
    ) internal pure {
        require(getRoot(startingIndex_, leaves_, proofElements_) == root_, InvalidProof());
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
        uint256[] calldata proofElements_
    ) internal pure returns (uint256 root_) {
        return _getRoot(startingIndex_, _getReversedLeafNodesFromLeaves(leaves_), proofElements_);
    }

    /* ============ Helper Functions ============ */

    /**
     * @notice Counts number of set bits (1's) in 64-bit unsigned integer.
     * @dev    See https://en.wikipedia.org/wiki/Hamming_weight implementation `popcount64b`.
     * @param  n_        The number to count the set bits of.
     * @return bitCount_ The number of set bits in `n_`.
     * @dev    Literals are inlined as they are very specific to this algorithm/function, and actually improve
     *         readability, given their patterns.
     */
    function _bitCount64(uint256 n_) internal pure returns (uint256 bitCount_) {
        require(n_ <= type(uint64).max, InvalidBitCount64Input());

        n_ -= (n_ >> 1) & 0x5555555555555555;
        n_ = (n_ & 0x3333333333333333) + ((n_ >> 2) & 0x3333333333333333);
        n_ = (n_ + (n_ >> 4)) & 0x0f0f0f0f0f0f0f0f;
        n_ += n_ >> 8;
        n_ += n_ >> 16;
        n_ += n_ >> 32;

        return n_ & 0x7f;
    }

    /**
     * @notice Rounds a 64-bit unsigned integer up to the nearest power of 2.
     * @param  n_        The number to round up to the nearest power of 2.
     * @return powerOf2_ The nearest power of 2 to `n_`.
     * @dev    Literals are inlined as they are very specific to this algorithm/function, and actually improve
     *         readability, given their patterns.
     */
    function _roundUpToPowerOf2(uint256 n_) internal pure returns (uint256 powerOf2_) {
        require(n_ <= type(uint64).max, InvalidRoundUpToPowerOf2Input());

        if (_bitCount64(n_) == 1) return n_;

        n_ |= n_ >> 1;
        n_ |= n_ >> 2;
        n_ |= n_ >> 4;
        n_ |= n_ >> 8;
        n_ |= n_ >> 16;
        n_ |= n_ >> 32;

        return n_ + 1;
    }

    /**
     * @notice Gets the balanced leaf count for a sequential merkle proof.
     * @param  leafCount_         The number of leaves in the merkle tree.
     * @return balancedLeafCount_ The balanced leaf count.
     */
    function _getBalancedLeafCount(uint256 leafCount_) internal pure returns (uint256 balancedLeafCount_) {
        require(leafCount_ != 0, NoLeaves());

        return leafCount_ == 1 ? 2 : _roundUpToPowerOf2(leafCount_);
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
        uint256[] memory hashes_,
        uint256[] calldata proofElements_
    ) internal pure returns (uint256 root_) {
        require(hashes_.length > 0, NoLeaves());
        require(proofElements_.length > 0, NoProofElements());
        require(startingIndex_ + hashes_.length <= proofElements_[0], InvalidProof());

        uint256 count_ = hashes_.length;
        uint256[] memory treeIndices_ = new uint256[](count_);

        uint256 readIndex_;
        uint256 writeIndex_;
        uint256 proofIndex_ = 1; // proofElements_[0] is the total leaf count, and is already consumed.
        uint256 upperBound_ = _getBalancedLeafCount(proofElements_[0]) + proofElements_[0] - 1;
        uint256 lowestTreeIndex_ = _getBalancedLeafCount(proofElements_[0]) + startingIndex_;
        uint256 highestLeafNodeIndex_ = lowestTreeIndex_ + count_ - 1;

        while (true) {
            // Instead of doing aa full pass through the empty tree indices array to build a starting sequential set of
            // indices, we can just check if we are in that "first pass" by checking if `readIndex_ < count_`, and if so
            // compute the index as needed given the `highestLeafNodeIndex_` and the `readIndex_`.
            uint256 nodeIndex_ = readIndex_ < count_
                ? highestLeafNodeIndex_ - readIndex_
                : treeIndices_[readIndex_ % count_];

            // If we reach the sub-root (i.e. `nodeIndex_ == 1`), we can return the root (i.e. `nodeIndex_ == 0`) by
            // hashing the tree's leaf count with the last computed hash.
            if (nodeIndex_ == 1) return _hashRoot(proofElements_[0], hashes_[(writeIndex_ - 1) % count_]);

            // If node index we are handling is the upper bound and is even, then it's sibling to the right does not
            // exist (since this is an unbalanced tree), so we can just copy the hash up one level.
            if ((nodeIndex_ == upperBound_) && _isEven(nodeIndex_)) {
                hashes_[writeIndex_ % count_] = _hashPairlessNode(hashes_[readIndex_++ % count_]);
                treeIndices_[writeIndex_++ % count_] = nodeIndex_ >> 1;

                // If we are not at the lowest tree index (i.e. there are nodes to the left that we have yet to process
                // at this level), then continue.
                if (nodeIndex_ != lowestTreeIndex_) continue;

                // If we are at the lowest tree index (i.e. there are no nodes to the left that we have yet to process
                // at this level), then we can update the lower bound and upper bound for the next level up.
                lowestTreeIndex_ >>= 1;
                upperBound_ >>= 1;

                continue;
            }

            // Instead of doing aa full pass through the empty tree indices array to build a starting sequential set of
            // indices, we can just check if we are in that "first pass" by checking if `readIndex_ + 1 < count_`, and
            // if so compute the next index as needed given the `highestLeafNodeIndex_` and the `readIndex_`.
            uint256 nextNodeIndex_ = (readIndex_ + 1) < count_
                ? highestLeafNodeIndex_ - (readIndex_ + 1)
                : treeIndices_[(readIndex_ + 1) % count_];

            // Since we are processing nodes from right to left, then if the current node index is even, and there
            // exists nodes to the right (or else the previous if-continue would have been hit), then the right part of
            // the hash is a decommitment. If the current node index is odd, then the right part of the hash we already
            // have computed.
            // NOTE: This is the right part, but reusing the return `root_` variable to save much needed stack space.
            root_ = _isEven(nodeIndex_) ? proofElements_[proofIndex_++] : hashes_[readIndex_++ % count_];

            // Based on the current node index and the next node index, we can determine if the left part of the hash
            // is an existing computed hash or a decommitment.
            uint256 left_ = _isLeftAnExistingHash(nodeIndex_, nextNodeIndex_)
                ? hashes_[readIndex_++ % count_]
                : proofElements_[proofIndex_++];

            hashes_[writeIndex_ % count_] = _hashNodePair(left_, root_);
            treeIndices_[writeIndex_++ % count_] = nodeIndex_ >> 1;

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
        return _isEven(nodeIndex_) || (nextNodeIndex_ == nodeIndex_ - 1);
    }

    /**
     * @notice Hashes a leaf of arbitrary size into a 32-byte leaf node.
     * @param  leaf_ The leaf to hash.
     * @return hash_ The hash of the leaf.
     */
    function _hashLeaf(bytes calldata leaf_) internal pure returns (uint256 hash_) {
        return uint256(keccak256(abi.encodePacked(LEAF_PREFIX, leaf_)));
    }

    /**
     * @notice Hashes a pair of 32-byte nodes into a 32-byte parent node.
     * @param  leftNode_  The left node to hash.
     * @param  rightNode_ The right node to hash.
     * @return hash_      The hash of the pair of nodes.
     */
    function _hashNodePair(uint256 leftNode_, uint256 rightNode_) internal pure returns (uint256 hash_) {
        return uint256(keccak256(abi.encodePacked(NODE_PREFIX, leftNode_, rightNode_)));
    }

    /**
     * @notice Hashes a 32-byte node, without a right paired node, into a 32-byte parent node.
     * @param  node_ The node to hash.
     * @return hash_ The hash of the node.
     */
    function _hashPairlessNode(uint256 node_) internal pure returns (uint256 hash_) {
        return uint256(keccak256(abi.encodePacked(NODE_PREFIX, node_)));
    }

    /**
     * @notice Hashes the topmost 32-byte node in the tree, combined with the tree's lead count, into a 32-byte root.
     * @param  leafCount_ The number of leaves in the merkle tree.
     * @param  node_      The topmost node in the tree.
     * @return hash_      The root hash of the tree.
     */
    function _hashRoot(uint256 leafCount_, uint256 node_) internal pure returns (uint256 hash_) {
        return uint256(keccak256(abi.encodePacked(ROOT_PREFIX, leafCount_, node_)));
    }

    /// @notice Get leaf nodes from arbitrary size leaves in calldata, in reverse order.
    function _getReversedLeafNodesFromLeaves(
        bytes[] calldata leaves_
    ) internal pure returns (uint256[] memory leafNodes_) {
        uint256 count_ = leaves_.length;
        leafNodes_ = new uint256[](count_);
        uint256 readIndex_ = count_;
        uint256 writeIndex_;

        while (writeIndex_ < count_) {
            leafNodes_[writeIndex_++] = _hashLeaf(leaves_[--readIndex_]);
        }
    }
}
