import { IPayerReportManager } from "./interfaces/IPayerReportManager.sol";

import { ERC5267 } from "../abstract/ERC5267.sol";
import { Migratable } from "../abstract/Migratable.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";

// TODO: If a node signer can sign for more than one node, their signature for a payer report will be identical, and
//       therefore replayable across their nodes. This may not be ideal, so it might be necessary to include the node ID
//       in the digest that is signed by the node signer, or otherwise differentiate signatures between nodes with the
//       same signer.

contract PayerReportManager is IPayerReportManager, Initializable, Migratable, ERC5267 {
    // ... (rest of the unchanged file)
    // Enforces that the end sequence ID is greater than or equal to the start sequence ID.
    if (endSequenceId_ < startSequenceId_) revert InvalidSequenceIds();

    _enforceNodeIdsMatchRegistry(nodeIds_);

    // Verifies the signatures and gets the array of valid signing node IDs.
    uint32[] memory validSigningNodeIds_ = _verifySignatures({
        originatorNodeId_: originatorNodeId_,
        startSequenceId_: startSequenceId_,
        endSequenceId_: endSequenceId_,
        endMinuteSinceEpoch_: endMinuteSinceEpoch_,
        payersMerkleRoot_: payersMerkleRoot_,
        nodeIds_: nodeIds_,
        signatures_: signatures_
    });
    // ... (rest of unchanged file)
    uint8 requiredSignatureCount_ = uint8((nodeIds_.length / 2) + 1);
    if (validSignatureCount_ < requiredSignatureCount_) {
        revert InsufficientSignatures(validSignatureCount_, requiredSignatureCount_);
    }
    // ... (rest unchanged)
    function _enforceNodeIdsMatchRegistry(uint32[] calldata nodeIds_) internal view {
        INodeRegistry.NodeWithId[] memory all = INodeRegistry(nodeRegistry).getAllNodes();
        uint8 canonicalCount = INodeRegistry(nodeRegistry).canonicalNodesCount();
        if (nodeIds_.length != canonicalCount) {
            revert NodeIdsLengthMismatch(uint32(canonicalCount), uint32(nodeIds_.length));
        }
        uint256 j = 0; // index into nodeIds_ (submitted)
        uint32 prev = 0; // for strictly-increasing check on submitted ids
        for (uint256 i = 0; i < all.length; ) {
            if (all[i].node.isCanonical) {
                uint32 expectedId = all[i].nodeId;
                uint32 actualId = nodeIds_[j];
                if (j > 0) {
                    if (actualId <= prev) revert UnorderedNodeIds();
                }
                if (actualId != expectedId) {
                    revert NodeIdAtIndexMismatch(expectedId, actualId, uint32(j));
                }
                prev = actualId;
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
        if (j != canonicalCount) {
            revert InternalStateCorrupted();
        }
    }
}