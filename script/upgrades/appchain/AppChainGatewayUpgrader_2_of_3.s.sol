// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice Step 2 of 3: Bridge the migrator parameter from settlement chain to app chain
 * @dev This script:
 *      - Sets the migrator address in the parameter registry on the settlement chain
 *      - Bridges the parameter to the app chain via the settlement chain gateway
 *
 * The value for MIGRATOR_ADDRESS is output by script 1_of_3.
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader_2_of_3 --rpc-url base_sepolia --slow --sig "Bridge(address)" <MIGRATOR_ADDRESS> --broadcast
 *
 * Manually wait until bridging is complete before proceeding to script 3_of_3.
 */
contract AppChainGatewayUpgrader_2_of_3 is BaseAppChainUpgrader {
    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.gatewayProxy;
    }

    function _getContractName() internal pure override returns (string memory name_) {
        return "appChainGateway";
    }

    function _deployOrGetImplementation(
        address,
        address,
        address
    ) internal pure override returns (address) {
        revert("Not used in step 2");
    }
}
