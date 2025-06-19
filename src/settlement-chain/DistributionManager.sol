// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";

import { IDistributionManager } from "./interfaces/IDistributionManager.sol";
import { IERC20Like, INodeRegistryLike, IPayerRegistryLike, IPayerReportManagerLike } from "./interfaces/External.sol";
import { IMigratable } from "../abstract/interfaces/IMigratable.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation of the Distribution Manager.
 * @notice This contract handles functionality for distributing fees.
 */
contract DistributionManager is IDistributionManager, Initializable, Migratable {
    /* ============ Constants/Immutables ============ */

    /// @dev One hundred percent (in basis points).
    uint16 internal constant _ONE_HUNDRED_PERCENT = 10_000;

    /// @inheritdoc IDistributionManager
    address public immutable parameterRegistry;

    /// @inheritdoc IDistributionManager
    address public immutable nodeRegistry;

    /// @inheritdoc IDistributionManager
    address public immutable payerReportManager;

    /// @inheritdoc IDistributionManager
    address public immutable payerRegistry;

    /// @inheritdoc IDistributionManager
    address public immutable token;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.DistributionManager
     * @notice The UUPS storage for the distribution manager.
     */
    struct DistributionManagerStorage {
        address protocolFeesDestination;
        uint96 owedProtocolFees;
        mapping(uint32 originatorNodeId => mapping(uint256 payerReportIndex => bool areClaimed)) areProtocolFeesClaimed;
        mapping(uint32 nodeId => uint96 owedFees) owedFees;
        mapping(uint32 nodeId => mapping(uint32 originatorNodeId => mapping(uint256 payerReportIndex => bool areClaimed))) areFeesClaimed;
        uint96 totalOwedFees;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.DistributionManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _DISTRIBUTION_MANAGER_STORAGE_LOCATION =
        0xecaf10aa029fa936ea42e5f15011e2f38c8598ffef434459a36a3d154fde2a00;

    function _getDistributionManagerStorage() internal pure returns (DistributionManagerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _DISTRIBUTION_MANAGER_STORAGE_LOCATION
        }
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_  The address of the parameter registry.
     * @param  nodeRegistry_       The address of the node registry.
     * @param  payerReportManager_ The address of the payer report manager.
     * @param  payerRegistry_      The address of the payer registry.
     * @param  token_              The address of the token.
     * @dev    The parameter registry, node registry, payer report manager, payer registry, and token must not be the
     *         zero address.
     * @dev    The parameter registry, node registry, payer report manager, payer registry, and token are immutable so
     *         that they are inlined in the contract code, and have minimal gas cost.
     */
    constructor(
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address token_
    ) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(nodeRegistry = nodeRegistry_)) revert ZeroNodeRegistry();
        if (_isZero(payerReportManager = payerReportManager_)) revert ZeroPayerReportManager();
        if (_isZero(payerRegistry = payerRegistry_)) revert ZeroPayerRegistry();
        if (_isZero(token = token_)) revert ZeroToken();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IDistributionManager
    function initialize() public initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IDistributionManager
    function claimProtocolFees(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external returns (uint96 claimed_) {
        IPayerReportManagerLike.PayerReport[] memory payerReports_ = _getPayerReports(
            originatorNodeIds_,
            payerReportIndices_
        );

        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        for (uint256 index_; index_ < payerReports_.length; ++index_) {
            // This makes the assumption that the returned array of payer reports from `_getPayerReports` is of the same
            // length, and in the same order, as the arrays of originator node IDs and payer report indices.
            uint32 originatorNodeId_ = originatorNodeIds_[index_];
            uint256 payerReportIndex_ = payerReportIndices_[index_];

            if ($.areProtocolFeesClaimed[originatorNodeId_][payerReportIndex_]) {
                revert AlreadyClaimed(originatorNodeId_, payerReportIndex_);
            }

            IPayerReportManagerLike.PayerReport memory payerReport_ = payerReports_[index_];

            if (!payerReport_.isSettled) revert PayerReportNotSettled(originatorNodeId_, payerReportIndex_);

            $.areProtocolFeesClaimed[originatorNodeId_][payerReportIndex_] = true;

            unchecked {
                uint96 protocolFees_ = uint96(
                    (uint256(payerReport_.feesSettled) * payerReport_.protocolFeeRate) / _ONE_HUNDRED_PERCENT
                );

                claimed_ += protocolFees_;

                emit ProtocolFeesClaim(originatorNodeId_, payerReportIndex_, protocolFees_);
            }
        }

        unchecked {
            $.owedProtocolFees += claimed_;
        }
    }

    /// @inheritdoc IDistributionManager
    function claim(
        uint32 nodeId_,
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external returns (uint96 claimed_) {
        _revertIfNotNodeOwner(nodeId_);

        IPayerReportManagerLike.PayerReport[] memory payerReports_ = _getPayerReports(
            originatorNodeIds_,
            payerReportIndices_
        );

        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        for (uint256 index_; index_ < payerReports_.length; ++index_) {
            // This makes the assumption that the returned array of payer reports from `_getPayerReports` is of the same
            // length, and in the same order, as the arrays of originator node IDs and payer report indices.
            uint32 originatorNodeId_ = originatorNodeIds_[index_];
            uint256 payerReportIndex_ = payerReportIndices_[index_];

            if ($.areFeesClaimed[nodeId_][originatorNodeId_][payerReportIndex_]) {
                revert AlreadyClaimed(originatorNodeId_, payerReportIndex_);
            }

            IPayerReportManagerLike.PayerReport memory payerReport_ = payerReports_[index_];

            if (!payerReport_.isSettled) revert PayerReportNotSettled(originatorNodeId_, payerReportIndex_);

            if (!_isInNodeIds(nodeId_, payerReport_.nodeIds)) {
                revert NotInPayerReport(originatorNodeId_, payerReportIndex_);
            }

            $.areFeesClaimed[nodeId_][originatorNodeId_][payerReportIndex_] = true;

            unchecked {
                uint96 netFees_ = uint96(
                    (uint256(payerReport_.feesSettled) * (_ONE_HUNDRED_PERCENT - payerReport_.protocolFeeRate)) /
                        _ONE_HUNDRED_PERCENT
                );

                // `payerReport_.nodeIds.length` must be at least 1 for `_isInNodeIds` to have returned `true`.
                uint96 feePortion_ = netFees_ / uint96(payerReport_.nodeIds.length);

                claimed_ += feePortion_;

                emit Claim(nodeId_, originatorNodeId_, payerReportIndex_, feePortion_);
            }
        }

        unchecked {
            $.owedFees[nodeId_] += claimed_;
            $.totalOwedFees += claimed_;
        }
    }

    /// @inheritdoc IDistributionManager
    function withdrawProtocolFees() external returns (uint96 withdrawn_) {
        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        uint96 owedProtocolFees_ = $.owedProtocolFees;

        withdrawn_ = _makeWithdrawableAmount(owedProtocolFees_);

        unchecked {
            // `withdrawn_` is less than or equal to `owedProtocolFees_`.
            $.owedProtocolFees = owedProtocolFees_ - withdrawn_;
        }

        // slither-disable-next-line reentrancy-events
        emit ProtocolFeesWithdrawal(withdrawn_);

        address protocolFeesDestination_ = $.protocolFeesDestination;

        if (_isZero(protocolFeesDestination_)) revert ZeroProtocolFeesDestination();

        SafeTransferLib.safeTransfer(token, protocolFeesDestination_, withdrawn_);
    }

    /// @inheritdoc IDistributionManager
    function withdraw(uint32 nodeId_, address destination_) external returns (uint96 withdrawn_) {
        if (_isZero(destination_)) revert ZeroDestination();

        _revertIfNotNodeOwner(nodeId_);

        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        uint96 owedFees_ = $.owedFees[nodeId_];

        withdrawn_ = _makeWithdrawableAmount(owedFees_);

        unchecked {
            // `withdrawn_` is less than or equal to `owedFees_`, and `totalOwedFees` is the sum of all `owedFees`.
            $.owedFees[nodeId_] = owedFees_ - withdrawn_;
            $.totalOwedFees -= withdrawn_;
        }

        // slither-disable-next-line reentrancy-events
        emit Withdrawal(nodeId_, withdrawn_);

        SafeTransferLib.safeTransfer(token, destination_, withdrawn_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /// @inheritdoc IDistributionManager
    function updateProtocolFeesDestination() external {
        address protocolFeesDestination_ = RegistryParameters.getAddressParameter(
            parameterRegistry,
            protocolFeesDestinationParameterKey()
        );

        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        if ($.protocolFeesDestination == protocolFeesDestination_) revert NoChange();

        emit ProtocolFeesDestinationUpdated($.protocolFeesDestination = protocolFeesDestination_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IDistributionManager
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.distributionManager.migrator";
    }

    /// @inheritdoc IDistributionManager
    function protocolFeesDestinationParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.distributionManager.protocolFeesDestination";
    }

    /// @inheritdoc IDistributionManager
    function protocolFeesDestination() external view returns (address protocolFeesDestination_) {
        return _getDistributionManagerStorage().protocolFeesDestination;
    }

    /// @inheritdoc IDistributionManager
    function totalOwedFees() external view returns (uint96 totalOwedFees_) {
        return _getDistributionManagerStorage().totalOwedFees;
    }

    /// @inheritdoc IDistributionManager
    function owedProtocolFees() external view returns (uint96 owedProtocolFees_) {
        return _getDistributionManagerStorage().owedProtocolFees;
    }

    /// @inheritdoc IDistributionManager
    function getOwedFees(uint32 nodeId_) external view returns (uint96 owedFees_) {
        return _getDistributionManagerStorage().owedFees[nodeId_];
    }

    /// @inheritdoc IDistributionManager
    function areProtocolFeesClaimed(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (bool areClaimed_) {
        return _getDistributionManagerStorage().areProtocolFeesClaimed[originatorNodeId_][payerReportIndex_];
    }

    /// @inheritdoc IDistributionManager
    function areFeesClaimed(
        uint32 nodeId_,
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (bool hasClaimed_) {
        return _getDistributionManagerStorage().areFeesClaimed[nodeId_][originatorNodeId_][payerReportIndex_];
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Returns the amount of fees that can be withdrawn given an amount owed and the contract's balance, and, if
     *         needed, tries to pull any excess fees from the payer registry.
     * @param  owed_         The amount of fees owed.
     * @return withdrawable_ The amount of fees that can be withdrawn.
     */
    function _makeWithdrawableAmount(uint96 owed_) internal returns (uint96 withdrawable_) {
        if (owed_ == 0) revert NoFeesOwed();

        uint96 available_ = uint96(IERC20Like(token).balanceOf(address(this)));

        if (owed_ > available_) {
            unchecked {
                available_ += IPayerRegistryLike(payerRegistry).sendExcessToFeeDistributor();
            }
        }

        // slither-disable-next-line incorrect-equality
        if (available_ == 0) revert ZeroAvailableBalance();

        // Only up to what is available is withdrawable.
        return available_ >= owed_ ? owed_ : available_;
    }

    /* ============ Internal View/Pure Functions ============ */

    function _getPayerReports(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) internal view returns (IPayerReportManagerLike.PayerReport[] memory payerReports_) {
        if (originatorNodeIds_.length != payerReportIndices_.length) revert ArrayLengthMismatch();

        return IPayerReportManagerLike(payerReportManager).getPayerReports(originatorNodeIds_, payerReportIndices_);
    }

    /// @dev Returns true if the node ID is in the list of node IDs.
    function _isInNodeIds(uint32 nodeId_, uint32[] memory nodeIds_) internal pure returns (bool isInNodeIds_) {
        for (uint256 index_; index_ < nodeIds_.length; ++index_) {
            if (nodeIds_[index_] == nodeId_) return true;
        }

        return false;
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _revertIfNotNodeOwner(uint32 nodeId_) internal view {
        if (INodeRegistryLike(nodeRegistry).ownerOf(nodeId_) != msg.sender) revert NotNodeOwner();
    }
}
