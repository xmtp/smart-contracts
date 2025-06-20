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
     * @notice Emitted when protocol fees are claimed.
     * @param  originatorNodeId The ID of the originator node of the payer report.
     * @param  payerReportIndex The index of the payer report.
     * @param  amount           The amount of protocol fees claimed.
     */
    event ProtocolFeesClaim(uint32 indexed originatorNodeId, uint256 indexed payerReportIndex, uint96 amount);

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
     * @notice Emitted when protocol fees are withdrawn.
     * @param  amount The amount of protocol fees withdrawn.
     */
    event ProtocolFeesWithdrawal(uint96 amount);

    /**
     * @notice Emitted when a withdrawal of owed fees is made.
     * @param  nodeId The ID of the node.
     * @param  amount The amount of tokens withdrawn.
     */
    event Withdrawal(uint32 indexed nodeId, uint96 amount);

    /**
     * @notice Emitted when the pause status is set.
     * @param  paused The new pause status.
     */
    event PauseStatusUpdated(bool indexed paused);

    /**
     * @notice Emitted when the protocol fees recipient is updated.
     * @param  protocolFeesRecipient The new protocol fees recipient.
     */
    event ProtocolFeesRecipientUpdated(address protocolFeesRecipient);

    /* ============ Custom Errors ============ */

    /// @notice Thrown when the parameter registry address is being set to zero (i.e. address(0)).
    error ZeroParameterRegistry();

    /// @notice Thrown when the node registry address is being set to zero (i.e. address(0)).
    error ZeroNodeRegistry();

    /// @notice Thrown when the payer report manager address is being set to zero (i.e. address(0)).
    error ZeroPayerReportManager();

    /// @notice Thrown when the payer registry address is being set to zero (i.e. address(0)).
    error ZeroPayerRegistry();

    /// @notice Thrown when the fee token address is being set to zero (i.e. address(0)).
    error ZeroFeeToken();

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

    /// @notice Thrown when the recipient address is zero (i.e. address(0)).
    error ZeroRecipient();

    /// @notice Thrown when the node has no fees owed.
    error NoFeesOwed();

    /// @notice Thrown when the contract's available balance is zero.
    error ZeroAvailableBalance();

    /// @notice Thrown when the contract is paused.
    error Paused();

    /// @notice Thrown when there is no change to an updated parameter.
    error NoChange();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    /**
     * @notice Claims protocol fees.
     * @param  originatorNodeIds_  The IDs of the originator nodes of the payer reports.
     * @param  payerReportIndices_ The payer report indices for each of the respective originator node IDs.
     * @return claimed_            The amount of protocol fees claimed.
     */
    function claimProtocolFees(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external returns (uint96 claimed_);

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
     * @notice Withdraws protocol fees.
     * @return withdrawn_ The amount of protocol fees withdrawn.
     */
    function withdrawProtocolFees() external returns (uint96 withdrawn_);

    /**
     * @notice Withdraws protocol fees, unwrapped as underlying token.
     * @return withdrawn_ The amount of protocol fees withdrawn.
     */
    function withdrawProtocolFeesIntoUnderlying() external returns (uint96 withdrawn_);

    /**
     * @notice Withdraws fees for a node.
     * @param  nodeId_    The ID of the node.
     * @param  recipient_ The address to withdraw the fee tokens to.
     * @return withdrawn_ The amount of fee tokens withdrawn.
     */
    function withdraw(uint32 nodeId_, address recipient_) external returns (uint96 withdrawn_);

    /**
     * @notice Withdraws fees for a node, unwrapped as underlying fee token.
     * @param  nodeId_    The ID of the node.
     * @param  recipient_ The address to withdraw the underlying fee tokens to.
     * @return withdrawn_ The amount of fee tokens withdrawn.
     */
    function withdrawIntoUnderlying(uint32 nodeId_, address recipient_) external returns (uint96 withdrawn_);

    /**
     * @notice Updates the pause status.
     * @dev    Ensures the new pause status is not equal to the old pause status.
     */
    function updatePauseStatus() external;

    /**
     * @notice Updates the protocol fees recipient.
     */
    function updateProtocolFeesRecipient() external;

    /* ============ View/Pure Functions ============ */

    /// @notice The parameter registry key used to fetch the migrator.
    function migratorParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the paused status.
    function pausedParameterKey() external pure returns (string memory key_);

    /// @notice The parameter registry key used to fetch the protocol fees recipient.
    function protocolFeesRecipientParameterKey() external pure returns (string memory key_);

    /// @notice The address of the parameter registry.
    function parameterRegistry() external view returns (address parameterRegistry_);

    /// @notice The address of the node registry.
    function nodeRegistry() external view returns (address nodeRegistry_);

    /// @notice The address of the payer report manager.
    function payerReportManager() external view returns (address payerReportManager_);

    /// @notice The address of the payer registry.
    function payerRegistry() external view returns (address payerRegistry_);

    /// @notice The address of the fee token.
    function feeToken() external view returns (address feeToken_);

    /// @notice The address of the protocol fees recipient.
    function protocolFeesRecipient() external view returns (address protocolFeesRecipient_);

    /// @notice The amount of claimed protocol fees owed to the protocol.
    function owedProtocolFees() external view returns (uint96 owedProtocolFees_);

    /// @notice The total amount of fees owed.
    function totalOwedFees() external view returns (uint96 totalOwedFees_);

    /// @notice The pause status.
    function paused() external view returns (bool paused_);

    /**
     * @notice Returns the amount of claimed fees owed to a node.
     * @param  nodeId_   The ID of the node.
     * @return owedFees_ The amount of fees owed.
     */
    function getOwedFees(uint32 nodeId_) external view returns (uint96 owedFees_);

    /**
     * @notice Returns whether protocol fees associated with a settled payer report have been claimed.
     * @param  originatorNodeId_ The ID of the originator node of the payer report.
     * @param  payerReportIndex_ The index of the payer report.
     * @return areClaimed_       Whether protocol fees associated with a settled payer report have been claimed.
     */
    function areProtocolFeesClaimed(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (bool areClaimed_);

    /**
     * @notice Returns whether a node has claimed fees associated with a settled payer report.
     * @param  nodeId_           The ID of the node.
     * @param  originatorNodeId_ The ID of the originator node of the payer report.
     * @param  payerReportIndex_ The index of the payer report.
     * @return areClaimed_       Whether the node has claimed fees associated with a settled payer report.
     */
    function areFeesClaimed(
        uint32 nodeId_,
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (bool areClaimed_);
}
