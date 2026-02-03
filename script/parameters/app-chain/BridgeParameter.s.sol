// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { ISettlementChainGateway } from "../../../src/settlement-chain/interfaces/ISettlementChainGateway.sol";
import { IERC20Like } from "../../Interfaces.sol";
import { BaseAppChainUpgrader } from "../../upgrades/app-chain/BaseAppChainUpgrader.s.sol";

/**
 * @title  Push a single parameter from settlement chain parameter registry to app chain parameter registry
 * @notice Pushes a single parameter key-value pair from the SettlementChainParameterRegistry to the
 *         AppChainParameterRegistry via the SettlementChainGateway. The caller must have sufficient token balances.
 */
contract BridgeParameter is BaseAppChainUpgrader {
    function push(string memory key_) external {
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

    // Required abstract method implementations (not used for parameter bridging)
    function _getProxy() internal pure override returns (address proxy_) {
        return address(0);
    }

    function _getContractName() internal pure override returns (string memory name_) {
        return "bridgeParameter";
    }

    function _getImplementationAddress(address) internal pure override returns (address impl_) {
        return address(0);
    }

    function _deployOrGetImplementation(
        address,
        address,
        address
    ) internal pure override returns (address implementation_) {
        return address(0);
    }

    function _getContractState(address) internal pure override returns (bytes memory state_) {
        return "";
    }

    function _isContractStateEqual(bytes memory, bytes memory) internal pure override returns (bool isEqual_) {
        return false;
    }

    function _logContractState(string memory, bytes memory) internal pure override {}
}
