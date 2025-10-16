// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC5267 } from "../../abstract/interfaces/IERC5267.sol";
import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";
import { ISequentialMerkleProofsErrors } from "../../libraries/interfaces/ISequentialMerkleProofsErrors.sol";

/**
 * @title  The interface for the Payer Report Manager.
 * @notice This interface exposes functionality for submitting and settling payer reports.
 */
interface IPayerReportManager is IMigratable, IERC5267, IRegistryParametersErrors, ISequentialMerkleProofsErrors {
    /* ============ Structs ============ */

    /**
     * @notice Represents a payer report.
     * @param  startSequenceId     The start sequence ID.
     * @param  endSequenceId       The end sequence ID.
     * @param  endMinuteSinceEpoch The timestamp of the message at `endSequenceId`.
     * @param  feesSettled         The total fees already settled for this report.
     * @param  offset              The next index in the Merkle tree that has yet to be processed/settled.
     * @param  isSettled           Whether the payer report is completely processed/settled.
     * @param  protocolFeeRate     The portion of the fees settled that is reserved for the protocol.
     * @param  payersMerkleRoot    The payers Merkle root.
     * @param  nodeIds             The active node IDs during the reporting period.
     */
    struct PayerReport {
        uint64 startSequenceId;
        uint64 endSequenceId;
        uint32 endMinuteSinceEpoch;
        uint96 feesSettled;
        uint32 offset;
        bool isSettled;
        uint16 protocolFeeRate;
        bytes32 payersMerkleRoot;
        uint32[] nodeIds;
    }

    /**
     * @notice Represents a payer report signature.
     * @param  nodeId    The node ID.
     * @param  signature The signature by the node operator.
     */
    struct PayerReportSignature {
        uint32 nodeId;
        bytes signature;
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when a payer report is submitted.
     * @param  originatorNodeId    The originator node ID.
     * @param  payerReportIndex    The index of the newly stored report.
     * @param  startSequenceId     The start sequence ID.
     * @param  endSequenceId       The end sequence ID.
     * @param  endMinuteSinceEpoch The timestamp of the message at `endSequenceId`.
     * @param  payersMerkleRoot    The payers Merkle root.
     * @param  nodeIds             The active node IDs during the reporting period.
     * @param  signingNodeIds      The node IDs of the signers of the payer report.
     */
    event PayerReportSubmitted(
        uint32 indexed originatorNodeId,
        uint256 indexed payerReportIndex,
        uint64 startSequenceId,
        uint64 indexed endSequenceId,
        uint32 endMinuteSinceEpoch,
        bytes32 payersMerkleRoot,
        uint32[] nodeIds,
        uint32[] signingNodeIds
    );

    /**
     * @notice Emitted when a subset of a payer report is settled.
     * @param  originatorNodeId The originator node ID.
     * @param  payerReportIndex The payer report index.
     * @param  count            The number of payer fees settled in this subset.
     * @param  remaining        The number of payer fees remaining to be settled.
     * @param  feesSettled      The amount of fees settled in this subset.
     */
    event PayerReportSubsetSettled(
        uint32 indexed originatorNodeId,
        uint256 indexed payerReportIndex,
        uint32 count,
        uint32 remaining,
        uint96 feesSettled
    );

    /**
     * @notice Emitted when the protocol fee rate is updated.
     * @param  protocolFeeRate The new protocol fee rate.
     */
    event ProtocolFeeRateUpdated(uint16 protocolFeeRate);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the node registry address is being set to zero (i.e. address(0)).
    error ZeroNodeRegistry();

    /// @notice Thrown when the payer registry address is being set to zero (i.e. address(0)).
    error ZeroPayerRegistry();

    /// @notice Thrown when the start sequence ID is not the last end sequence ID.
    error InvalidStartSequenceId(uint64 startSequenceId, uint64 lastSequenceId);

    /// @notice Thrown when the start and end sequence IDs are invalid.
    error InvalidSequenceIds();

    /// @notice Thrown when the signing node IDs are not ordered and unique.
    error UnorderedNodeIds();

    /// @notice Thrown when the number of valid signatures is insufficient.
    error InsufficientSignatures(uint8 validSignatureCount, uint8 requiredSignatureCount);

    /// @notice Thrown when the payer report has already been submitted.
    error PayerReportAlreadySubmitted(uint32 originatorNodeId, uint64 startSequenceId, uint64 endSequenceId);

    /// @notice Thrown when the payer report index is out of bounds.
    error PayerReportIndexOutOfBounds();

    /// @notice Thrown when the payer report has already been entirely settled.
    error PayerReportEntirelySettled();

    /// @notice Thrown when the length of the payer fees array is too long.
    error PayerFeesLengthTooLong();

    /// @notice Thrown when failing to settle usage via the payer registry.
    error SettleUsageFailed(bytes returnData_);

    /// @notice Thrown when the lengths of input arrays don't match.
    error ArrayLengthMismatch();

    /// @notice Thrown when the protocol fee rate is invalid.
    error InvalidProtocolFeeRate();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /// @notice Thrown when there are no payer reports found for the given originator node ID.
    /// @param  originatorNodeId The ID of the originator node for which no reports exist.
    error NoReportsForOriginator(uint32 originatorNodeId);

    /// @notice Thrown when the provided node IDs do not exactly match the registry set.
    error NodeIdsLengthMismatch(uint32 expectedCount, uint32 providedCount);

    /// @notice Element at `index` does not match the canonical node id at that position.
    error NodeIdAtIndexMismatch(uint32 expectedId, uint32 actualId, uint32 index);

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Submits a payer report.
     * @param  originatorNodeId_    The originator node ID.
     * @param  startSequenceId_     The start sequence ID.
     * @param  endSequenceId_       The end sequence ID.
     * @param  endMinuteSinceEpoch_ The timestamp of the message at `endSequenceId`.
     * @param  payersMerkleRoot_    The payers Merkle root.
     * @param  nodeIds_             The active node IDs during the reporting period.
     * @param  signatures_          The signature objects for the payer report.
     * @return payerReportIndex_    The index of the payer report in the originator's payer report array.
     */
    function submit(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_,
        PayerReportSignature[] calldata signatures_
    ) external returns (uint256 payerReportIndex_);

    /**
     * @notice Settles a subset of a payer report.
     * @param  originatorNodeId_ The originator node ID.
     * @param  payerReportIndex_ The payer report index.
     * @param  payerFees_        The sequential payer fees to settle.
     * @param  proofElements_    The sequential Merkle proof elements for the payer fees to settle.
     */
    function settle(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_,
        bytes[] calldata payerFees_,
        bytes32[] calldata proofElements_
    ) external;

    /**
     * @notice Updates the protocol fee rate.
     */
    function updateProtocolFeeRate() external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the EIP712 typehash used in the encoding of a signed digest for a payer report.
    // slither-disable-next-line naming-convention
    function PAYER_REPORT_TYPEHASH() external pure returns (bytes32 payerReportTypehash_);

    /// @notice One hundred percent (in basis points).
    // slither-disable-next-line naming-convention
    function ONE_HUNDRED_PERCENT() external pure returns (uint16 oneHundredPercent_);

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the protocol fee rate.
    function protocolFeeRateParameterKey() external pure returns (string memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the node registry.
    function nodeRegistry() external view returns (address nodeRegistry_);

    /// @notice The address of the payer registry.
    function payerRegistry() external view returns (address payerRegistry_);

    /// @notice The protocol fee rate (in basis points).
    function protocolFeeRate() external view returns (uint16 protocolFeeRate_);

    /**
     * @notice Returns an array of specific payer reports.
     * @param  originatorNodeIds_  An array of originator node IDs.
     * @param  payerReportIndices_ An array of payer report indices for each of the respective originator node IDs.
     * @return payerReports_       The array of payer reports.
     * @dev    The node IDs in `originatorNodeIds_` don't need to be unique.
     */
    function getPayerReports(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external view returns (PayerReport[] memory payerReports_);

    /**
     * @notice Returns a payer report.
     * @param  originatorNodeId_ The originator node ID.
     * @param  payerReportIndex_ The payer report index.
     * @return payerReport_      The payer report.
     */
    function getPayerReport(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (PayerReport memory payerReport_);

    /**
     * @notice Returns the EIP-712 digest for a payer report.
     * @param  originatorNodeId_    The originator node ID.
     * @param  startSequenceId_     The start sequence ID.
     * @param  endSequenceId_       The end sequence ID.
     * @param  endMinuteSinceEpoch_ The timestamp of the message at `endSequenceId`.
     * @param  payersMerkleRoot_    The payers Merkle root.
     * @param  nodeIds_             The active node IDs during the reporting period.
     * @return digest_              The EIP-712 digest.
     */
    function getPayerReportDigest(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_
    ) external view returns (bytes32 digest_);
}
