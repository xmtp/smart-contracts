// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC5267 } from "../../abstract/interfaces/IERC5267.sol";
import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

/**
 * @title  The interface for the Payer Report Manager.
 * @notice This interface exposes functionality for submitting and settling payer reports.
 */
interface IPayerReportManager is IMigratable, IERC5267 {
    /* ============ Structs ============ */

    /**
     * @notice Represents a payer report.
     * @param  startSequenceId  The start sequence ID.
     * @param  endSequenceId    The end sequence ID.
     * @param  feesSettled      The total fees already settled for this report.
     * @param  offset           The next index in the merkle tree that has yet to be processed/settled.
     * @param  isSettled        Whether the payer report is completely processed/settled.
     * @param  payersMerkleRoot The payers merkle root.
     * @param  nodeIds          The active node IDs during the reporting period.
     */
    struct PayerReport {
        uint32 startSequenceId;
        uint32 endSequenceId;
        uint96 feesSettled;
        uint32 offset;
        bool isSettled;
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
     * @param  originatorNodeId The originator node ID.
     * @param  payerReportIndex The index of the newly stored report.
     * @param  startSequenceId  The start sequence ID.
     * @param  endSequenceId    The end sequence ID.
     * @param  payersMerkleRoot The payers merkle root.
     * @param  nodeIds          The active node IDs during the reporting period.
     * @param  signingNodeIds   The node IDs of the signers of the payer report.
     */
    event PayerReportSubmitted(
        uint32 indexed originatorNodeId,
        uint256 indexed payerReportIndex,
        uint32 startSequenceId,
        uint32 indexed endSequenceId,
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

    /* ============ Custom Errors ============ */

    /// @notice Error thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Error thrown when the node registry address is being set to zero (i.e. address(0)).
    error ZeroNodeRegistry();

    /// @notice Error thrown when the payer registry address is being set to zero (i.e. address(0)).
    error ZeroPayerRegistry();

    /// @notice Error thrown when the start sequence ID is not the last end sequence ID.
    error InvalidStartSequenceId(uint32 startSequenceId, uint32 lastSequenceId);

    /// @notice Error thrown when the start and end sequence IDs are invalid.
    error InvalidSequenceIds();

    /// @notice Error thrown when the signing node IDs are not ordered and unique.
    error UnorderedNodeIds();

    /// @notice Error thrown when the number of valid signatures is insufficient.
    error InsufficientSignatures(uint8 validSignatureCount, uint8 requiredSignatureCount);

    /// @notice Error thrown when the payer report index is out of bounds.
    error PayerReportIndexOutOfBounds();

    /// @notice Error thrown when the payer report has already been entirely settled.
    error PayerReportEntirelySettled();

    /// @notice Error thrown when failing to settle usage via the payer registry.
    error SettleUsageFailed(bytes returnData_);

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Submits a payer report.
     * @param  originatorNodeId_ The originator node ID.
     * @param  startSequenceId_  The start sequence ID.
     * @param  endSequenceId_    The end sequence ID.
     * @param  payersMerkleRoot_ The payers merkle root.
     * @param  nodeIds_          The active node IDs during the reporting period.
     * @param  signatures_       The signature objects for the payer report.
     * @return payerReportIndex_ The index of the payer report in the originator's payer report array.
     */
    function submit(
        uint32 originatorNodeId_,
        uint32 startSequenceId_,
        uint32 endSequenceId_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_,
        PayerReportSignature[] calldata signatures_
    ) external returns (uint256 payerReportIndex_);

    /**
     * @notice Settles a subset of a payer report.
     * @param  originatorNodeId_ The originator node ID.
     * @param  payerReportIndex_ The payer report index.
     * @param  payerFees_        The sequential payer fees to settle.
     * @param  proofElements_    The sequential merkle proof elements for the payer fees to settle.
     */
    function settle(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_,
        bytes[] calldata payerFees_,
        bytes32[] calldata proofElements_
    ) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the node registry.
    function nodeRegistry() external view returns (address nodeRegistry_);

    /// @notice The address of the payer registry.
    function payerRegistry() external view returns (address payerRegistry_);

    /**
     * @notice Returns the payer reports for an originator node.
     * @param  originatorNodeId_ The originator node ID.
     * @return payerReports_     The array of payer reports.
     */
    function getPayerReports(uint32 originatorNodeId_) external view returns (PayerReport[] memory payerReports_);

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
     * @param  originatorNodeId_ The originator node ID.
     * @param  startSequenceId_  The start sequence ID.
     * @param  endSequenceId_    The end sequence ID.
     * @param  payersMerkleRoot_ The payers merkle root.
     * @param  nodeIds_          The active node IDs during the reporting period.
     * @return digest_           The EIP-712 digest.
     */
    function getPayerReportDigest(
        uint32 originatorNodeId_,
        uint32 startSequenceId_,
        uint32 endSequenceId_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_
    ) external view returns (bytes32 digest_);
}
