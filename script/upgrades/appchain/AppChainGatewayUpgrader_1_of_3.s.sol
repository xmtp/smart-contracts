// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AppChainGateway } from "../../../src/app-chain/AppChainGateway.sol";
import { AppChainGatewayDeployer } from "../../deployers/AppChainGatewayDeployer.sol";
import { BaseAppChainUpgrader } from "./BaseAppChainUpgrader.s.sol";

/**
 * @notice Step 1 of 3: Prepare the upgrade on the app chain
 * @dev This script:
 *      - Captures contract state before upgrade
 *      - Deploys or gets the implementation
 *      - Deploys a GenericEIP1967Migrator
 *      - Outputs the migrator address for use in the script 2_of_3.
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader_1_of_3 --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 */
contract AppChainGatewayUpgrader_1_of_3 is BaseAppChainUpgrader {
    function _getProxy() internal view override returns (address proxy_) {
        return _deployment.gatewayProxy;
    }

    function _getContractName() internal pure override returns (string memory name_) {
        return "appChainGateway";
    }

    function _deployOrGetImplementation(
        address factory_,
        address paramRegistry_,
        address proxy_
    ) internal override returns (address implementation_) {
        // Get settlement chain gateway from proxy
        AppChainGateway gateway = AppChainGateway(proxy_);
        address settlementChainGateway_ = gateway.settlementChainGateway();

        // Compute implementation address
        address computedImpl = AppChainGatewayDeployer.getImplementation(
            factory_,
            paramRegistry_,
            settlementChainGateway_
        );

        // Skip deployment if implementation already exists
        if (computedImpl.code.length > 0) {
            console.log("Implementation already exists at computed address, skipping deployment");
            return computedImpl;
        }

        // Deploy new implementation
        (implementation_, ) = AppChainGatewayDeployer.deployImplementation(
            factory_,
            paramRegistry_,
            settlementChainGateway_
        );
    }
}
