// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IMigratable } from "../../abstract/interfaces/IMigratable.sol";

interface ISettlementChainGateway is IMigratable {
    /* ============ Events ============ */

    event SenderFundsDeposited(address indexed inbox_, uint256 indexed messageNumber, uint256 amount);

    event ParametersSent(
        address indexed inbox_,
        uint256 indexed messageNumber,
        uint256 indexed nonce,
        bytes[][] keyChains_
    );

    /* ============ Custom Errors ============ */

    error ZeroRegistryAddress();

    error ZeroAppChainGatewayAddress();

    error ZeroAppChainNativeTokenAddress();

    error ApproveFailed();

    error TransferFailed();

    error NoInboxes();

    error NoKeyChains();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     */
    function initialize() external;

    /* ============ Interactive Functions ============ */

    function depositSenderFunds(address inbox_, uint256 amount_) external;

    function sendParameters(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_
    ) external;

    function sendParametersAsRetryableTickets(
        address[] calldata inboxes_,
        bytes[][] calldata keyChains_,
        uint256 gasLimit_,
        uint256 gasPrice_,
        uint256 maxSubmissionCost_,
        uint256 nativeTokensToSend_
    ) external;

    /* ============ View/Pure Functions ============ */

    function migratorParameterKey() external pure returns (bytes memory key_);

    function registry() external view returns (address registry_);

    function appChainGateway() external view returns (address appChainGateway_);

    function appChainAlias() external view returns (address appChainAlias_);

    function appChainNativeToken() external view returns (address appChainNativeToken_);
}
