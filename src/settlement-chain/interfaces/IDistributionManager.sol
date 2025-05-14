// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";
import { IRegistryParametersErrors } from "../../libraries/interfaces/IRegistryParametersErrors.sol";

/**
 * @title  The interface for the Distribution Manager.
 * @notice This interface exposes functionality for distributing fees.
 */
interface IDistributionManager is IMigratable, IRegistryParametersErrors {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a claim is made.
     * @param  nodeId           The ID of the node.
     * @param  originatorNodeId The ID of the originator node of the payer report.
     * @param  payerReportIndex The index of the payer report.
     * @param  amount           The amount of fees claimed.
     */
    event Claim(
        uint32 indexed nodeId,
        uint32 indexed originatorNodeId,
        uint256 indexed payerReportIndex,
        uint96 amount
    );

    /**
     * @notice Emitted when a withdrawal of owed fees is made.
     * @param  nodeId The ID of the node.
     * @param  amount The amount of tokens withdrawn.
     */
    event Withdrawal(uint32 indexed nodeId, uint96 amount);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the node registry address is being set to zero (i.e. address(0)).
    error ZeroNodeRegistry();

    /// @notice Thrown when the payer report manager address is being set to zero (i.e. address(0)).
    error ZeroPayerReportManager();

    /// @notice Thrown when the payer registry address is being set to zero (i.e. address(0)).
    error ZeroPayerRegistry();

    /// @notice Thrown when the token address is being set to zero (i.e. address(0)).
    error ZeroToken();

    /// @notice Thrown when the caller is not the owner of the specified node.
    error NotNodeOwner();

    /// @notice Thrown when the length of two input arrays do not match when they should.
    error ArrayLengthMismatch();

    /// @notice Thrown when a payer report has already been claimed.
    error AlreadyClaimed(uint32 originatorNodeId, uint256 payerReportIndex);

    /// @notice Thrown when the payer report is not settled.
    error PayerReportNotSettled(uint32 originatorNodeId, uint256 payerReportIndex);

    /// @notice Thrown when the node ID is not in a payer report.
    error NotInPayerReport(uint32 originatorNodeId, uint256 payerReportIndex);

    /// @notice Thrown when the destination address is zero (i.e. address(0)).
    error ZeroDestination();

    /// @notice Thrown when the node has no fees owed.
    error NoFeesOwed();

    /// @notice Thrown when the contract's available balance is zero.
    error ZeroAvailableBalance();

    /**
     * @notice Thrown when the `ERC20.transfer` call fails.
     * @dev    This is an identical redefinition of `SafeTransferLib.TransferFailed`.
     */
    error TransferFailed();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Claims fees for a node for an array of payer reports.
     * @param  nodeId_             The ID of the node.
     * @param  originatorNodeIds_  The IDs of the originator nodes of the payer reports.
     * @param  payerReportIndices_ The payer report indices for each of the respective originator node IDs.
     * @return claimed_            The amount of fees claimed.
     * @dev    The node IDs in `originatorNodeIds_` do not need to be unique.
     */
    function claim(
        uint32 nodeId_,
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external returns (uint96 claimed_);

    /**
     * @notice Withdraws fees for a node.
     * @param  nodeId_      The ID of the node.
     * @param  destination_ The address to withdraw the fees to.
     * @return withdrawn_   The amount of fees withdrawn.
     */
    function withdraw(uint32 nodeId_, address destination_) external returns (uint96 withdrawn_);

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (bytes memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the node registry.
    function nodeRegistry() external view returns (address nodeRegistry_);

    /// @notice The address of the payer report manager.
    function payerReportManager() external view returns (address payerReportManager_);

    /// @notice The address of the payer registry.
    function payerRegistry() external view returns (address payerRegistry_);

    /// @notice The address of the token.
    function token() external view returns (address token_);

    /// @notice The total amount of fees owed.
    function totalOwedFees() external view returns (uint96 totalOwedFees_);

    /**
     * @notice Returns the amount of claimed fees owed to a node.
     * @param  nodeId_   The ID of the node.
     * @return owedFees_ The amount of fees owed.
     */
    function getOwedFees(uint32 nodeId_) external view returns (uint96 owedFees_);

    /**
     * @notice Returns whether a node has claimed a payer report.
     * @param  nodeId_           The ID of the node.
     * @param  originatorNodeId_ The ID of the originator node of the payer report.
     * @param  payerReportIndex_ The index of the payer report.
     * @return hasClaimed_       Whether the node has claimed fees associated with a settled payer report.
     */
    function getHasClaimed(
        uint32 nodeId_,
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (bool hasClaimed_);
}
