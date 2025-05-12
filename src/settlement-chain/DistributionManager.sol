// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SafeTransferLib } from "../../lib/solady/src/utils/SafeTransferLib.sol";

import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { IDistributionManager } from "./interfaces/IDistributionManager.sol";
import {
    IParameterRegistryLike,
    INodeRegistryLike,
    IPayerReportManagerLike,
    IERC20Like
} from "./interfaces/External.sol";

import { Migratable } from "../abstract/Migratable.sol";

/**
 * @title  Implementation of the Distribution Manager.
 * @notice This contract handles functionality for distributing fees.
 */
contract DistributionManager is IDistributionManager, Initializable, Migratable {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IDistributionManager
    address public immutable parameterRegistry;

    /// @inheritdoc IDistributionManager
    address public immutable nodeRegistry;

    /// @inheritdoc IDistributionManager
    address public immutable payerReportManager;

    /// @inheritdoc IDistributionManager
    address public immutable token;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.DistributionManager
     * @notice The UUPS storage for the distribution manager.
     */
    struct DistributionManagerStorage {
        mapping(uint32 nodeId => mapping(uint32 originatorNodeId => mapping(uint256 payerReportIndex => bool hasClaimed))) hasClaimed;
        mapping(uint32 nodeId => uint96 owedFees) owedFees;
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
     * @param  token_              The address of the token.
     * @dev    The parameter registry, node registry, and payer report manager must not be the zero address.
     * @dev    The parameter registry, node registry, and payer report manager are immutable so that they are inlined
     *         in the contract code, and have minimal gas cost.
     */
    constructor(address parameterRegistry_, address nodeRegistry_, address payerReportManager_, address token_) {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(nodeRegistry = nodeRegistry_)) revert ZeroNodeRegistry();
        if (_isZero(payerReportManager = payerReportManager_)) revert ZeroPayerReportManager();
        if (_isZero(token = token_)) revert ZeroToken();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IDistributionManager
    function initialize() public initializer {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IDistributionManager
    function claim(
        uint32 nodeId_,
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external returns (uint96 claimed_) {
        _revertIfNotNodeOwner(nodeId_);

        IPayerReportManagerLike.PayerReport[] memory payerReports_ = IPayerReportManagerLike(payerReportManager)
            .getPayerReports(originatorNodeIds_, payerReportIndices_);

        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        for (uint256 index_; index_ < payerReports_.length; ++index_) {
            // This makes the assumption that the returned array of payer reports from `getPayerReports` is of the same
            // length, and in the same order, as the arrays of originator node IDs and payer report indices.
            uint32 originatorNodeId_ = originatorNodeIds_[index_];
            uint256 payerReportIndex_ = payerReportIndices_[index_];

            if ($.hasClaimed[nodeId_][originatorNodeId_][payerReportIndex_]) {
                revert AlreadyClaimed(originatorNodeId_, payerReportIndex_);
            }

            IPayerReportManagerLike.PayerReport memory payerReport_ = payerReports_[index_];

            if (!payerReport_.isSettled) revert PayerReportNotSettled(originatorNodeId_, payerReportIndex_);

            uint32[] memory nodeIds_ = payerReport_.nodeIds;

            if (!_isInNodeIds(nodeId_, nodeIds_)) {
                revert NotInPayerReport(originatorNodeId_, payerReportIndex_);
            }

            $.hasClaimed[nodeId_][originatorNodeId_][payerReportIndex_] = true;

            // `nodeIds_.length` must be at least 1 for `_isInNodeIds` to have returned `true`.
            uint96 feePortion_ = payerReport_.feesSettled / uint96(nodeIds_.length);

            unchecked {
                claimed_ += feePortion_;
            }

            emit Claim(nodeId_, originatorNodeId_, payerReportIndex_, feePortion_);
        }

        unchecked {
            $.owedFees[nodeId_] += claimed_;
            $.totalOwedFees += claimed_;
        }
    }

    /// @inheritdoc IDistributionManager
    function withdraw(uint32 nodeId_, address destination_) external returns (uint96 withdrawn_) {
        if (_isZero(destination_)) revert ZeroDestination();

        _revertIfNotNodeOwner(nodeId_);

        DistributionManagerStorage storage $ = _getDistributionManagerStorage();

        uint96 owedFees_ = $.owedFees[nodeId_];

        if (owedFees_ == 0) revert NoFeesOwed();

        uint96 availableBalance_ = uint96(IERC20Like(token).balanceOf(address(this)));

        // slither-disable-next-line incorrect-equality
        if (availableBalance_ == 0) revert ZeroAvailableBalance();

        // Only withdraw up to what is available.
        withdrawn_ = availableBalance_ >= owedFees_ ? owedFees_ : availableBalance_;

        unchecked {
            // `withdrawn_` is less than or equal to `owedFees_`, and `totalOwedFees` is the sum of all `owedFees`.
            $.owedFees[nodeId_] = owedFees_ - withdrawn_;
            $.totalOwedFees -= withdrawn_;
        }

        emit Withdrawal(nodeId_, withdrawn_);

        SafeTransferLib.safeTransfer(token, destination_, withdrawn_);
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        _migrate(_toAddress(_getRegistryParameter(migratorParameterKey())));
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IDistributionManager
    function migratorParameterKey() public pure returns (bytes memory key_) {
        return "xmtp.distributionManager.migrator";
    }

    /// @inheritdoc IDistributionManager
    function totalOwedFees() external view returns (uint96 totalOwedFees_) {
        return _getDistributionManagerStorage().totalOwedFees;
    }

    /// @inheritdoc IDistributionManager
    function getOwedFees(uint32 nodeId_) external view returns (uint96 owedFees_) {
        return _getDistributionManagerStorage().owedFees[nodeId_];
    }

    /// @inheritdoc IDistributionManager
    function getHasClaimed(
        uint32 nodeId_,
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (bool hasClaimed_) {
        return _getDistributionManagerStorage().hasClaimed[nodeId_][originatorNodeId_][payerReportIndex_];
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns true if the node ID is in the list of node IDs.
    function _isInNodeIds(uint32 nodeId_, uint32[] memory nodeIds_) internal pure returns (bool isInNodeIds_) {
        for (uint256 index_; index_ < nodeIds_.length; ++index_) {
            if (nodeIds_[index_] == nodeId_) return true;
        }

        return false;
    }

    function _getRegistryParameter(bytes memory key_) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry).get(key_);
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    function _toAddress(bytes32 value_) internal pure returns (address address_) {
        // slither-disable-next-line assembly
        assembly {
            address_ := value_
        }
    }

    function _revertIfNotNodeOwner(uint32 nodeId_) internal view {
        if (INodeRegistryLike(nodeRegistry).ownerOf(nodeId_) != msg.sender) revert NotNodeOwner();
    }
}
