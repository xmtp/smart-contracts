// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISettlementGateway {
    /* ============ Structs ============ */

    /* ============ Events ============ */

    /* ============ Custom Errors ============ */

    error ZeroRegistryAddress();

    error ZeroAppchainGatewayAddress();

    error ZeroAppchainNativeTokenAddress();

    error ZeroAdminAddress();

    error ZeroImplementationAddress();

    error NotAdmin();

    error ApproveFailed();

    error TransferFailed();

    error EmptyKeys();

    /* ============ Initialization ============ */

    /**
     * @notice Initializes the contract.
     * @param  admin_ The address of the admin.
     */
    function initialize(address admin_) external;

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

    function admin() external view returns (address admin_);

    function registry() external view returns (address registry_);

    function appchainGateway() external view returns (address appchainGateway_);

    function appchainAlias() external view returns (address appchainAlias_);

    function appchainNativeToken() external view returns (address appchainNativeToken_);
}
