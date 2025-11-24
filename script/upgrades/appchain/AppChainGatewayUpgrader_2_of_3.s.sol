// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { IParameterRegistry } from "../../../src/abstract/interfaces/IParameterRegistry.sol";
import { ISettlementChainGateway } from "../../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IERC20Like } from "../../Interfaces.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @notice Step 2 of 3: Bridge the migrator parameter from settlement chain to app chain
 * @dev This script:
 *      - Sets the migrator address in the parameter registry on the settlement chain
 *      - Bridges the parameter to the app chain via the settlement chain gateway
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader_2_of_3 --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast 
 */
contract AppChainGatewayUpgrader_2_of_3 is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();
    error GatewayProxyNotSet();
    error UnexpectedChainId();
    error InsufficientBalance();

    uint256 internal constant _TX_STIPEND = 21_000;
    uint256 internal constant _GAS_PER_BRIDGED_KEY = 75_000;
    uint256 internal constant _APP_CHAIN_GAS_PRICE = 2_000_000_000; // 2 gwei per gas.

    string internal _environment;
    uint256 internal _privateKey;
    address internal _admin;
    Utils.DeploymentData internal _deployment;

    function setUp() external {
        // Environment
        _environment = vm.envString("ENVIRONMENT");
        if (bytes(_environment).length == 0) revert EnvironmentNotSet();
        console.log("Environment: %s", _environment);

        // Admin private key
        _deployment = Utils.parseDeploymentData(string.concat("config/", _environment, ".json"));
        _privateKey = uint256(vm.envBytes32("ADMIN_PRIVATE_KEY"));
        if (_privateKey == 0) revert PrivateKeyNotSet();
        _admin = vm.addr(_privateKey);
        console.log("Admin: %s", _admin);
    }

    function Bridge(address migrator_) external {
        if (_deployment.gatewayProxy == address(0)) revert GatewayProxyNotSet();
        if (block.chainid != _deployment.settlementChainId) revert UnexpectedChainId();

        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _deployment.gatewayProxy;

        console.log("paramRegistry: %s", paramRegistry);
        console.log("gatewayProxy (settlement chain): %s", proxy);
        console.log("migrator: %s", migrator_);
        console.log("appChainId: %s", _deployment.appChainId);

        // Get migrator parameter key
        string memory key = "xmtp.appChainGateway.migrator";
        console.log("migratorParameterKey: %s", key);

        vm.startBroadcast(_privateKey);

        // Set migrator in parameter registry
        IParameterRegistry(paramRegistry).set(key, bytes32(uint256(uint160(migrator_))));
        console.log("Set migrator in parameter registry");

        // Calculate gas and cost for bridging
        uint256 gasLimit_ = _TX_STIPEND + (_GAS_PER_BRIDGED_KEY * 1); // 1 key

        // Convert from 18 decimals (app chain gas token) to 6 decimals (fee token).
        uint256 cost_ = ((_APP_CHAIN_GAS_PRICE * gasLimit_) * 1e6) / 1e18;

        console.log("gasLimit: %s", gasLimit_);
        console.log("cost (fee token, 6 decimals): %s", cost_);

        if (IERC20Like(_deployment.feeTokenProxy).balanceOf(_admin) < cost_) revert InsufficientBalance();

        // Approve fee token
        IERC20Like(_deployment.feeTokenProxy).approve(proxy, cost_);

        // Bridge the parameter
        uint256[] memory chainIds_ = new uint256[](1);
        chainIds_[0] = _deployment.appChainId;

        string[] memory keys_ = new string[](1);
        keys_[0] = key;

        ISettlementChainGateway(proxy).sendParameters(chainIds_, keys_, gasLimit_, _APP_CHAIN_GAS_PRICE, cost_);

        console.log("Bridged migrator parameter to app chain");

        vm.stopBroadcast();
    }
}

