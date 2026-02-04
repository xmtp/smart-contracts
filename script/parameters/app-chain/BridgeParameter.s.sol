// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { ISettlementChainGateway } from "../../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { IERC20Like } from "../../Interfaces.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @title  Bridge and read parameters on the app chain parameter registry
 * @notice Provides two operations:
 *         - push(): Bridge a parameter from settlement chain to app chain (permissionless)
 *         - get(): Read a parameter value from the app chain parameter registry
 * @dev    Bridging is PERMISSIONLESS - no admin signature required. Only needs DEPLOYER_PRIVATE_KEY
 *         with sufficient fee tokens to pay for the bridge transaction.
 *
 * Usage (push - run against settlement chain):
 *   ENVIRONMENT=testnet-dev forge script BridgeParameter --rpc-url base_sepolia --slow --sig "push(string)" "xmtp.example.key" --broadcast
 *
 * Usage (get - run against app chain):
 *   ENVIRONMENT=testnet-dev forge script BridgeParameter --rpc-url xmtp_ropsten --sig "get(string)" "xmtp.example.key"
 *
 * Or use the helper script for push:
 *   ./dev/bridge-parameter testnet-dev xmtp.example.key
 */
contract BridgeParameter is Script {
    error EnvironmentNotSet();
    error PrivateKeyNotSet();
    error GatewayProxyNotSet();
    error UnexpectedChainId();
    error InsufficientBalance();

    uint256 internal constant _TX_STIPEND = 21_000;
    uint256 internal constant _GAS_PER_BRIDGED_KEY = 150_000;

    /// @dev Default value copied from Administration.s.sol
    /// On app chain, each gas unit costs 2 gwei (measured as fraction of the xUSD native token).
    /// Arbitrum L3 default is 0.1 gwei, but this fluctuates with demand.
    uint256 internal constant _APP_CHAIN_GAS_PRICE = 2_000_000_000;

    string internal _environment;
    uint256 internal _deployerPrivateKey;
    address internal _deployer;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Deployment data
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));

        // Deployer private key (optional - only needed for push(), not for get())
        try vm.envBytes32("DEPLOYER_PRIVATE_KEY") returns (bytes32 pk_) {
            _deployerPrivateKey = uint256(pk_);
            if (_deployerPrivateKey != 0) {
                _deployer = vm.addr(_deployerPrivateKey);
                console.log("Deployer: %s", _deployer);
            }
        } catch {}
    }

    function push(string memory key_) external {
        if (_deployerPrivateKey == 0) revert PrivateKeyNotSet();
        if (_deployment.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address proxy = _deployment.gatewayProxy;
        address feeToken = _deployment.feeTokenProxy;

        console.log("Settlement Chain Gateway: %s", proxy);
        console.log("Fee Token: %s", feeToken);
        console.log("App Chain ID: %s", _deployment.appChainId);
        console.log("Parameter key: %s", key_);

        // Calculate gas and cost for bridging
        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * 1); // 1 key to push

        // Convert from 18 decimals (app chain gas token) to 6 decimals (fee token).
        uint256 cost_ = ((_APP_CHAIN_GAS_PRICE * gasLimit_) * 1e6) / 1e18;

        console.log("Gas limit: %s", gasLimit_);
        console.log("Max fee per gas: %s (2 gwei)", _APP_CHAIN_GAS_PRICE);
        console.log("Cost (fee token, 6 decimals): %s", cost_);

        uint256 balance = IERC20Like(feeToken).balanceOf(_deployer);
        console.log("Fee token balance (deployer): %s", balance);

        if (balance < cost_) revert InsufficientBalance();

        vm.startBroadcast(_deployerPrivateKey);

        // Approve fee token
        IERC20Like(feeToken).approve(proxy, cost_);
        console.log("Approved fee token");

        // Bridge the parameter
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = _deployment.appChainId;

        string[] memory keys_ = new string[](1);
        keys_[0] = key_;

        uint256 totalSent_ = ISettlementChainGateway(proxy).sendParameters(
            chainIds_,
            keys_,
            gasLimit_,
            _APP_CHAIN_GAS_PRICE,
            cost_
        );

        console.log("Bridged parameter to app chain");
        console.log("Total fee tokens sent: %s", totalSent_);

        vm.stopBroadcast();
    }

    /**
     * @notice Gets the current value of a parameter from the app chain parameter registry
     * @param key_ The parameter key
     * @dev Run this against the app chain RPC to verify bridged parameters arrived
     *
     * Usage:
     *   ENVIRONMENT=testnet-dev forge script BridgeParameter --rpc-url xmtp_ropsten --sig "get(string)" "xmtp.example.key"
     */
    function get(string calldata key_) external view {
        address paramRegistry = _deployment.parameterRegistryProxy;

        console.log("App Chain Parameter Registry: %s", paramRegistry);
        console.log("Key: %s", key_);

        bytes32 value = IParameterRegistry(paramRegistry).get(key_);
        console.log("Value (bytes32):");
        console.logBytes32(value);
        console.log("Value (uint256): %s", uint256(value));
        console.log("Value (address): %s", address(uint160(uint256(value))));
    }
}
