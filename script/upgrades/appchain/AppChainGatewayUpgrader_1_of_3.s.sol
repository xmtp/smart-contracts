// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script, console } from "../../../lib/forge-std/src/Script.sol";
import { GenericEIP1967Migrator } from "../../../src/any-chain/GenericEIP1967Migrator.sol";
import { AppChainGateway } from "../../../src/app-chain/AppChainGateway.sol";
import { AppChainGatewayDeployer } from "../../deployers/AppChainGatewayDeployer.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @notice Step 1 of 3: Prepare the upgrade on the app chain
 * @dev This script:
 *      - Captures contract state before upgrade
 *      - Deploys or gets the implementation
 *      - Deploys a GenericEIP1967Migrator
 *      - Outputs the migrator address for use in step 2
 *
 * Usage:
 *   ENVIRONMENT=testnet-dev forge script AppChainGatewayUpgrader_1_of_3 --rpc-url xmtp_ropsten --slow --sig "Prepare()" --broadcast
 */
contract AppChainGatewayUpgrader_1_of_3 is Script {
    error PrivateKeyNotSet();
    error EnvironmentNotSet();

    struct ContractState {
        address parameterRegistry;
        address settlementChainGateway;
        address settlementChainGatewayAlias;
        bool paused;
    }

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

    function Prepare() external {
        address factory = _deployment.factory;
        address paramRegistry = _deployment.parameterRegistryProxy;
        address proxy = _deployment.gatewayProxy;

        console.log("factory: %s", factory);
        console.log("paramRegistry: %s", paramRegistry);
        console.log("proxy: %s", proxy);

        // Get contract state before upgrade
        bytes memory stateBefore = _getContractState(proxy);
        _logContractState("State before upgrade:", stateBefore);

        vm.startBroadcast(_privateKey);

        // Deploy or get implementation
        address newImpl = _deployOrGetImplementation(factory, paramRegistry, proxy);
        console.log("newImpl: %s", newImpl);

        // Deploy generic migrator
        GenericEIP1967Migrator migrator = new GenericEIP1967Migrator(newImpl);
        console.log("migrator: %s", address(migrator));

        vm.stopBroadcast();

        // Output migrator address for step 2
        console.log("==========================================");
        console.log("MIGRATOR_ADDRESS_FOR_STEP_2: %s", address(migrator));
        console.log("==========================================");
    }

    function _deployOrGetImplementation(
        address factory_,
        address paramRegistry_,
        address proxy_
    ) internal returns (address implementation_) {
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

    function _getContractState(address proxy_) internal view returns (bytes memory state_) {
        ContractState memory state = _getAppChainGatewayState(proxy_);
        return abi.encode(state);
    }

    function _getAppChainGatewayState(address proxy_) internal view returns (ContractState memory state_) {
        AppChainGateway gateway = AppChainGateway(proxy_);
        state_.parameterRegistry = gateway.parameterRegistry();
        state_.settlementChainGateway = gateway.settlementChainGateway();
        state_.settlementChainGatewayAlias = gateway.settlementChainGatewayAlias();
        state_.paused = gateway.paused();
    }

    function _logContractState(string memory title_, bytes memory state_) internal view {
        ContractState memory state = abi.decode(state_, (ContractState));
        console.log("%s", title_);
        console.log("  Parameter registry: %s", state.parameterRegistry);
        console.log("  Settlement chain gateway: %s", state.settlementChainGateway);
        console.log("  Settlement chain gateway alias: %s", state.settlementChainGatewayAlias);
        console.log("  Paused: %s", state.paused);
    }
}

