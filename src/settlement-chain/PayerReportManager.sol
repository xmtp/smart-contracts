// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ECDSA } from "../../lib/solady/src/utils/ECDSA.sol";
import { Initializable } from "../../lib/oz-upgradeable/contracts/proxy/utils/Initializable.sol";

import { RegistryParameters } from "../libraries/RegistryParameters.sol";
import { SequentialMerkleProofs } from "../libraries/SequentialMerkleProofs.sol";

import { IMigratable } from "../abstract/interfaces/IMigratable.sol";
import { INodeRegistryLike, IPayerRegistryLike } from "./interfaces/External.sol";
import { IPayerReportManager } from "./interfaces/IPayerReportManager.sol";

import { ERC5267 } from "../abstract/ERC5267.sol";
import { Migratable } from "../abstract/Migratable.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";

// TODO: If a node signer can sign for more than one node, their signature for a payer report will be identical, and
//       therefore replayable across their nodes. This may not be ideal, so it might be necessary to include the node ID
//       of the signing node in the digest.

/**
 * @title  Implementation of the Payer Report Manager.
 * @notice This contract handles functionality for submitting and settling payer reports.
 */
contract PayerReportManager is IPayerReportManager, Initializable, Migratable, ERC5267 {
    /* ============ Constants/Immutables ============ */

    // solhint-disable-next-line max-line-length
    /// @dev keccak256("PayerReport(uint32 originatorNodeId,uint64 startSequenceId,uint64 endSequenceId,uint32 endMinuteSinceEpoch,bytes32 payersMerkleRoot,uint32[] nodeIds)")
    bytes32 public constant PAYER_REPORT_TYPEHASH = 0x3737a2cced99bb28fc5aede45aa81d3ce0aa9137c5f417641835d0d71d303346;

    /// @inheritdoc IPayerReportManager
    uint16 public constant ONE_HUNDRED_PERCENT = 10_000;

    /// @inheritdoc IPayerReportManager
    address public immutable parameterRegistry;

    /// @inheritdoc IPayerReportManager
    address public immutable nodeRegistry;

    /// @inheritdoc IPayerReportManager
    address public immutable payerRegistry;

    /* ============ UUPS Storage ============ */

    /**
     * @custom:storage-location erc7201:xmtp.storage.PayerReportManager
     * @notice The UUPS storage for the payer report manager.
     * @param  payerReportsByOriginator The mapping of arrays of payer reports by originator node ID.
     */
    struct PayerReportManagerStorage {
        mapping(uint32 originatorId => PayerReport[] payerReports) payerReportsByOriginator;
        uint16 protocolFeeRate;
    }

    // keccak256(abi.encode(uint256(keccak256("xmtp.storage.PayerReportManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PAYER_REPORT_MANAGER_STORAGE_LOCATION =
        0x26b057ee8e4d60685198828fdf1c618ab8e36b0ab85f54a47b18319f6f718e00;

    function _getPayerReportManagerStorage() internal pure returns (PayerReportManagerStorage storage $) {
        // slither-disable-next-line assembly
        assembly {
            $.slot := _PAYER_REPORT_MANAGER_STORAGE_LOCATION
        }
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructor for the implementation contract, such that the implementation cannot be initialized.
     * @param  parameterRegistry_ The address of the parameter registry.
     * @param  nodeRegistry_      The address of the node registry.
     * @param  payerRegistry_     The address of the payer registry.
     * @dev    The parameter registry, node registry, and payer registry must not be the zero address.
     * @dev    The parameter registry, node registry, and payer registry are immutable so that they are inlined in the
     *         contract code, and have minimal gas cost.
     */
    constructor(address parameterRegistry_, address nodeRegistry_, address payerRegistry_) ERC5267() {
        if (_isZero(parameterRegistry = parameterRegistry_)) revert ZeroParameterRegistry();
        if (_isZero(nodeRegistry = nodeRegistry_)) revert ZeroNodeRegistry();
        if (_isZero(payerRegistry = payerRegistry_)) revert ZeroPayerRegistry();

        _disableInitializers();
    }

    /* ============ Initialization ============ */

    /// @inheritdoc IPayerReportManager
    function initialize() public initializer {
        _initializeERC5267();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPayerReportManager
    function submit(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_,
        PayerReportSignature[] calldata signatures_
    ) external returns (uint256 payerReportIndex_) {
        PayerReport[] storage payerReports_ = _getPayerReportManagerStorage().payerReportsByOriginator[
            originatorNodeId_
        ];

        payerReportIndex_ = payerReports_.length;

        uint64 lastSequenceId_ = payerReportIndex_ > 0 ? payerReports_[payerReportIndex_ - 1].endSequenceId : 0;

        if (payerReportIndex_ > 0) {
            bool isUnique_ = _verifyPayerReportIsUnique(
                payerReportIndex_,
                originatorNodeId_,
                startSequenceId_,
                endSequenceId_,
                endMinuteSinceEpoch_,
                payersMerkleRoot_,
                nodeIds_
            );

            if (!isUnique_) revert PayerReportAlreadySubmitted(originatorNodeId_, startSequenceId_, endSequenceId_);
        }

        // Enforces that the start sequence ID is the last end sequence ID.
        if (startSequenceId_ != lastSequenceId_) {
            revert InvalidStartSequenceId(startSequenceId_, lastSequenceId_);
        }

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

        payerReports_.push(
            PayerReport({
                startSequenceId: startSequenceId_,
                endSequenceId: endSequenceId_,
                endMinuteSinceEpoch: endMinuteSinceEpoch_,
                feesSettled: 0,
                offset: 0,
                isSettled: payersMerkleRoot_ == SequentialMerkleProofs.EMPTY_TREE_ROOT,
                protocolFeeRate: _getPayerReportManagerStorage().protocolFeeRate,
                payersMerkleRoot: payersMerkleRoot_,
                nodeIds: nodeIds_
            })
        );

        emit PayerReportSubmitted({
            originatorNodeId: originatorNodeId_,
            payerReportIndex: payerReportIndex_,
            startSequenceId: startSequenceId_,
            endSequenceId: endSequenceId_,
            endMinuteSinceEpoch: endMinuteSinceEpoch_,
            payersMerkleRoot: payersMerkleRoot_,
            nodeIds: nodeIds_,
            signingNodeIds: validSigningNodeIds_
        });

        if (payersMerkleRoot_ == SequentialMerkleProofs.EMPTY_TREE_ROOT) {
            emit PayerReportSubsetSettled(originatorNodeId_, payerReportIndex_, 0, 0, 0);
        }
    }

    /// @inheritdoc IPayerReportManager
    function settle(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_,
        bytes[] calldata payerFees_,
        bytes32[] calldata proofElements_
    ) external {
        PayerReport[] storage payerReports_ = _getPayerReportManagerStorage().payerReportsByOriginator[
            originatorNodeId_
        ];

        if (payerReportIndex_ >= payerReports_.length) revert PayerReportIndexOutOfBounds();

        PayerReport storage payerReport_ = payerReports_[payerReportIndex_];

        if (payerReport_.isSettled) revert PayerReportEntirelySettled();

        // Verify the payer fees provided are the next sequential payer fees from the last settled offset.
        SequentialMerkleProofs.verify(payerReport_.payersMerkleRoot, payerReport_.offset, payerFees_, proofElements_);

        // NOTE: It is safe to cast the length of the `payerFees_` to a `uint32` here, as an array of bytes (even if all
        //       empty) with length `type(uint32).max` will revert due to memory allocation before this.
        payerReport_.offset += uint32(payerFees_.length);

        uint32 leafCount_ = SequentialMerkleProofs.getLeafCount(proofElements_);

        payerReport_.isSettled = leafCount_ == payerReport_.offset;

        bytes32 digest_ = _getPayerReportDigest(
            originatorNodeId_,
            payerReport_.startSequenceId,
            payerReport_.endSequenceId,
            payerReport_.endMinuteSinceEpoch,
            payerReport_.payersMerkleRoot,
            payerReport_.nodeIds
        );

        // Low level call which handles passing the `payerFees_` arrays as a bytes array that will be automatically
        // decoded as the required structs by the payer registry's `settleUsage` function.
        (bool success_, bytes memory returnData_) = payerRegistry.call(
            abi.encodeWithSelector(IPayerRegistryLike.settleUsage.selector, digest_, payerFees_)
        );

        if (!success_) revert SettleUsageFailed(returnData_);

        uint96 feesSettled_ = abi.decode(returnData_, (uint96));

        // slither-disable-next-line reentrancy-events
        emit PayerReportSubsetSettled(
            originatorNodeId_,
            payerReportIndex_,
            uint32(payerFees_.length),
            leafCount_ - payerReport_.offset,
            feesSettled_
        );

        payerReport_.feesSettled += feesSettled_;
    }

    /// @inheritdoc IMigratable
    function migrate() external {
        // NOTE: No access control logic is enforced here, since the migrator is defined by some administered parameter.
        _migrate(RegistryParameters.getAddressParameter(parameterRegistry, migratorParameterKey()));
    }

    /// @inheritdoc IPayerReportManager
    function updateProtocolFeeRate() external {
        // NOTE: No access control logic is enforced here, since the value is defined by some administered parameter.
        uint16 protocolFeeRate_ = RegistryParameters.getUint16Parameter(
            parameterRegistry,
            protocolFeeRateParameterKey()
        );

        if (protocolFeeRate_ > ONE_HUNDRED_PERCENT) revert InvalidProtocolFeeRate();

        PayerReportManagerStorage storage $ = _getPayerReportManagerStorage();

        if ($.protocolFeeRate == protocolFeeRate_) revert NoChange();

        emit ProtocolFeeRateUpdated($.protocolFeeRate = protocolFeeRate_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPayerReportManager
    function migratorParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerReportManager.migrator";
    }

    /// @inheritdoc IPayerReportManager
    function protocolFeeRateParameterKey() public pure returns (string memory key_) {
        return "xmtp.payerReportManager.protocolFeeRate";
    }

    /// @inheritdoc IPayerReportManager
    function protocolFeeRate() external view returns (uint16 protocolFeeRate_) {
        return _getPayerReportManagerStorage().protocolFeeRate;
    }

    /// @inheritdoc IPayerReportManager
    function getPayerReportDigest(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_
    ) external view returns (bytes32 digest_) {
        return
            _getPayerReportDigest(
                originatorNodeId_,
                startSequenceId_,
                endSequenceId_,
                endMinuteSinceEpoch_,
                payersMerkleRoot_,
                nodeIds_
            );
    }

    /// @inheritdoc IPayerReportManager
    function getPayerReports(
        uint32[] calldata originatorNodeIds_,
        uint256[] calldata payerReportIndices_
    ) external view returns (PayerReport[] memory payerReports_) {
        if (originatorNodeIds_.length != payerReportIndices_.length) revert ArrayLengthMismatch();

        payerReports_ = new PayerReport[](originatorNodeIds_.length);
        PayerReportManagerStorage storage $ = _getPayerReportManagerStorage();

        for (uint256 i; i < originatorNodeIds_.length; ) {
            uint32 originatorNodeId_ = originatorNodeIds_[i];
            uint256 payerReportIndex_ = payerReportIndices_[i];

            PayerReport[] storage arr = $.payerReportsByOriginator[originatorNodeId_];
            uint256 len = arr.length;

            if (len == 0) revert NoReportsForOriginator(originatorNodeId_);
            if (payerReportIndex_ >= len) revert PayerReportIndexOutOfBounds();

            payerReports_[i] = arr[payerReportIndex_];

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IPayerReportManager
    function getPayerReport(
        uint32 originatorNodeId_,
        uint256 payerReportIndex_
    ) external view returns (PayerReport memory payerReport_) {
        PayerReport[] storage arr = _getPayerReportManagerStorage().payerReportsByOriginator[originatorNodeId_];

        uint256 length = arr.length;
        if (length == 0) revert NoReportsForOriginator(originatorNodeId_);
        if (payerReportIndex_ >= length) revert PayerReportIndexOutOfBounds();

        return arr[payerReportIndex_];
    }

    /* ============ Internal View/Pure Functions ============ */

    function _name() internal pure override returns (string memory name_) {
        return "PayerReportManager";
    }

    function _version() internal pure override returns (string memory version_) {
        return "1";
    }

    /**
     * @dev    Returns the EIP-712 digest for a payer report.
     * @param  originatorNodeId_ The ID of the node originator.
     * @param  startSequenceId_  The start sequence ID.
     * @param  endSequenceId_    The end sequence ID.
     * @param  payersMerkleRoot_ The payers Merkle root.
     * @param  nodeIds_          The active node IDs during the reporting period.
     * @return digest_           The EIP-712 digest.
     */
    function _getPayerReportDigest(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] memory nodeIds_
    ) internal view returns (bytes32 digest_) {
        return
            _getDigest(
                keccak256(
                    abi.encode(
                        PAYER_REPORT_TYPEHASH,
                        originatorNodeId_,
                        startSequenceId_,
                        endSequenceId_,
                        endMinuteSinceEpoch_,
                        payersMerkleRoot_,
                        keccak256(abi.encodePacked(nodeIds_))
                    )
                )
            );
    }

    function _isZero(address input_) internal pure returns (bool isZero_) {
        return input_ == address(0);
    }

    /**
     * @dev Verifies that a payer report is unique, compared to a payer report at a given index.
     * @param  lastPayerReportIndex_ The index of the last payer report.
     * @param  originatorNodeId_     The originator node ID.
     * @param  startSequenceId_      The start sequence ID.
     * @param  endSequenceId_        The end sequence ID.
     * @param  endMinuteSinceEpoch_  The timestamp of the message at `endSequenceId`.
     * @param  payersMerkleRoot_     The payers Merkle root.
     * @param  nodeIds_              The active node IDs during the reporting period.
     * @return isUnique_             Whether the report is unique.
     */
    function _verifyPayerReportIsUnique(
        uint256 lastPayerReportIndex_,
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_
    ) internal view returns (bool isUnique_) {
        PayerReport storage lastPayerReport_ = _getPayerReportManagerStorage().payerReportsByOriginator[
            originatorNodeId_
        ][lastPayerReportIndex_ - 1];

        bytes32 lastDigest_ = _getPayerReportDigest(
            originatorNodeId_,
            lastPayerReport_.startSequenceId,
            lastPayerReport_.endSequenceId,
            lastPayerReport_.endMinuteSinceEpoch,
            lastPayerReport_.payersMerkleRoot,
            lastPayerReport_.nodeIds
        );

        bytes32 newDigest_ = _getPayerReportDigest(
            originatorNodeId_,
            startSequenceId_,
            endSequenceId_,
            endMinuteSinceEpoch_,
            payersMerkleRoot_,
            nodeIds_
        );

        return lastDigest_ != newDigest_;
    }

    /**
     * @dev Verifies that enough of the signatures are valid and provided by canonical node operators and returns the
     *      array of valid signing node IDs.
     */
    function _verifySignatures(
        uint32 originatorNodeId_,
        uint64 startSequenceId_,
        uint64 endSequenceId_,
        uint32 endMinuteSinceEpoch_,
        bytes32 payersMerkleRoot_,
        uint32[] calldata nodeIds_,
        PayerReportSignature[] calldata signatures_
    ) internal view returns (uint32[] memory validSigningNodeIds_) {
        bytes32 digest_ = _getPayerReportDigest(
            originatorNodeId_,
            startSequenceId_,
            endSequenceId_,
            endMinuteSinceEpoch_,
            payersMerkleRoot_,
            nodeIds_
        );

        // Need to determine how many of the signatures are valid and provided by canonical node operators.
        uint8 validSignatureCount_ = 0;

        // This array will help in constructing the `validSigningNodeIds_` array, whose length may be less than
        // the length of the `signatures_` array if some of the signatures are invalid.
        bool[] memory isValid_ = new bool[](signatures_.length);

        for (uint256 index_; index_ < signatures_.length; ++index_) {
            uint32 nodeId_ = signatures_[index_].nodeId;

            // Enforces that the signing node IDs are ordered and unique.
            if (index_ != 0 && nodeId_ <= signatures_[index_ - 1].nodeId) revert UnorderedNodeIds();

            // If the signature is invalid, ignore it.
            if (!(isValid_[index_] = _verifySignature(digest_, nodeId_, signatures_[index_].signature))) continue;

            ++validSignatureCount_;
        }

        // the submitted nodeIds must match the current set of canonical NodeIds
        uint8 requiredSignatureCount_ = uint8((nodeIds_.length / 2) + 1);

        // Enforces that the number of valid signatures is greater than one more than half of the canonical node count.
        if (validSignatureCount_ < requiredSignatureCount_) {
            revert InsufficientSignatures(validSignatureCount_, requiredSignatureCount_);
        }

        validSigningNodeIds_ = new uint32[](validSignatureCount_);

        uint256 writeIndex_ = 0;

        for (uint256 index_; index_ < isValid_.length; ++index_) {
            if (!isValid_[index_]) continue; // Skip invalid signatures.

            unchecked {
                validSigningNodeIds_[writeIndex_++] = signatures_[index_].nodeId;
            }
        }
    }

    /// @dev Returns true if the signature is from the signer of a canonical node.
    function _verifySignature(
        bytes32 digest_,
        uint32 nodeId_,
        bytes calldata signature_
    ) internal view returns (bool isValid_) {
        // TODO: A combined fetch of `getIsCanonicalNode` and `getSigner` would be optimal.

        // If the node is not canonical, the signature is invalid.
        if (!INodeRegistryLike(nodeRegistry).getIsCanonicalNode(nodeId_)) return false;

        // Try to recover the signer from the signature. We don't want to revert if the signature is invalid.
        address signer_ = ECDSA.tryRecoverCalldata(digest_, signature_);

        // The signature is valid if the recovered signer is not `address(0)` and is the signer of the node.
        return !_isZero(signer_) && (signer_ == INodeRegistryLike(nodeRegistry).getSigner(nodeId_));
    }

    function _enforceNodeIdsMatchRegistry(uint32[] calldata nodeIds_) internal view {
        INodeRegistry.NodeWithId[] memory all = INodeRegistry(nodeRegistry).getAllNodes();

        uint256 nodeIdsLen = nodeIds_.length;
        uint256 len = all.length;

        uint256 j = 0; // index into submitted nodeIds_
        uint256 canon = 0; // count of canonical nodes discovered in registry
        uint32 prev = 0; // for strictly-increasing check on submitted IDs

        for (uint256 i = 0; i < len; ) {
            INodeRegistry.NodeWithId memory it = all[i];

            if (it.node.isCanonical) {
                unchecked {
                    ++canon;
                }

                // If the submitted list is shorter than the canonical set, skip comparisons
                // but keep counting canonicals so we can return the exact expected count.
                if (j < nodeIdsLen) {
                    uint32 actualId = nodeIds_[j];

                    // strictly increasing constraint on the submitted list
                    if (j != 0 && actualId <= prev) revert UnorderedNodeIds();

                    uint32 expectedId = it.nodeId;
                    if (actualId != expectedId) {
                        revert NodeIdAtIndexMismatch(expectedId, actualId, uint32(j));
                    }

                    prev = actualId;
                    unchecked {
                        ++j;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }

        if (canon != nodeIdsLen) {
            revert NodeIdsLengthMismatch(uint32(canon), uint32(nodeIdsLen));
        }
    }
}
