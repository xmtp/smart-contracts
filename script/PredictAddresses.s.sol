// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { console } from "../lib/forge-std/src/console.sol";
import { DeployScripts } from "./Deploy.s.sol";
import { Utils } from "./utils/Utils.sol";
import { Create2 } from "../lib/oz/contracts/utils/Create2.sol";
import { Proxy } from "../src/any-chain/Proxy.sol";
import { Factory } from "../src/any-chain/Factory.sol";
import { SettlementChainParameterRegistry } from "../src/settlement-chain/SettlementChainParameterRegistry.sol";
import { FeeToken } from "../src/settlement-chain/FeeToken.sol";
import { SettlementChainGateway } from "../src/settlement-chain/SettlementChainGateway.sol";
import { PayerRegistry } from "../src/settlement-chain/PayerRegistry.sol";
import { RateRegistry } from "../src/settlement-chain/RateRegistry.sol";
import { NodeRegistry } from "../src/settlement-chain/NodeRegistry.sol";
import { PayerReportManager } from "../src/settlement-chain/PayerReportManager.sol";
import { DistributionManager } from "../src/settlement-chain/DistributionManager.sol";
import { DepositSplitter } from "../src/settlement-chain/DepositSplitter.sol";
import { AppChainParameterRegistry } from "../src/app-chain/AppChainParameterRegistry.sol";
import { AppChainGateway } from "../src/app-chain/AppChainGateway.sol";
import { GroupMessageBroadcaster } from "../src/app-chain/GroupMessageBroadcaster.sol";
import { IdentityUpdateBroadcaster } from "../src/app-chain/IdentityUpdateBroadcaster.sol";
import { MockUnderlyingFeeToken } from "../test/utils/Mocks.sol";

/**
 * @title PredictAddressesScript
 * @notice Script to predict addresses for all deployment contracts (base and components)
 * @dev This script computes all implementation and proxy addresses needed for deployment
 *
 * IMPORTANT: The Factory proxy uses CREATE (not CREATE2), so its address depends on the deployer's nonce.
 *
 * Steps to use this script:
 * 1. Check deployer's current nonce on-chain: `cast nonce <deployer> --rpc-url <rpc>`
 * 2. Compute Factory proxy address: The Factory proxy will be at `vm.computeCreateAddress(deployer, nonce)`
 *    where nonce is the deployer's current nonce (it's the first contract deployed)
 * 3. Put Factory proxy address in config/mainnet.json
 * 4. Run this script to compute all other addresses (they use CREATE2 via Factory)
 * 5. Update config/mainnet.json with all computed addresses
 *
 * Usage: ENVIRONMENT=mainnet forge script PredictAddressesScript --rpc-url base_mainnet --sig "predictSettlementChainAddresses()"
 * Usage: ENVIRONMENT=mainnet forge script PredictAddressesScript --rpc-url xmtp_mainnet --sig "predictAppChainAddresses()"
 */
contract PredictAddressesScript is DeployScripts {
    function predictSettlementChainAddresses() external view {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();
        if (_deploymentData.underlyingFeeToken == address(0)) revert UnderlyingFeeTokenNotSet();

        address factory_ = _deploymentData.factory;
        uint64 deployerNonce_ = vm.getNonce(_deployer);

        console.log("\n=== Settlement Chain Address Predictions ===");
        console.log("Deployer:", _deployer);
        console.log("Deployer current nonce:", deployerNonce_);
        console.log("Factory Proxy (from config, should be at nonce", deployerNonce_, "):", factory_);
        console.log("");

        // Compute initializableImplementation address (created when Factory is initialized)
        address initializableImpl_ = vm.computeCreateAddress(factory_, 1);
        bytes32 proxyInitCodeHash_ = keccak256(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(initializableImpl_))
        );

        // Print BASE contracts
        _printBaseContracts(factory_, proxyInitCodeHash_);

        // Print COMPONENT contracts
        _printComponentContracts(factory_, proxyInitCodeHash_);
    }

    function _printBaseContracts(address factory_, bytes32 proxyInitCodeHash_) internal view {
        address paramRegProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.parameterRegistryProxySalt,
            proxyInitCodeHash_
        );
        address factoryImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(type(Factory).creationCode, abi.encode(paramRegProxy_))
        );
        address paramRegImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(type(SettlementChainParameterRegistry).creationCode)
        );
        address feeTokenProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.feeTokenProxySalt,
            proxyInitCodeHash_
        );
        address feeTokenImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(
                type(FeeToken).creationCode,
                abi.encode(paramRegProxy_, _deploymentData.underlyingFeeToken)
            )
        );
        address gatewayProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.gatewayProxySalt,
            proxyInitCodeHash_
        );
        address gatewayImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(
                type(SettlementChainGateway).creationCode,
                abi.encode(paramRegProxy_, gatewayProxy_, feeTokenProxy_)
            )
        );

        console.log("--- BASE CONTRACTS ---");
        _printContractPair("Factory", factory_, factoryImpl_);
        _printContractPair("SettlementChainParameterRegistry", paramRegProxy_, paramRegImpl_);

        if (_deploymentData.mockUnderlyingFeeTokenProxySalt != 0) {
            address mockUnderlyingImpl_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(
                    type(MockUnderlyingFeeToken).creationCode,
                    abi.encode(_deploymentData.underlyingFeeToken)
                )
            );
            address mockUnderlyingProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.mockUnderlyingFeeTokenProxySalt,
                proxyInitCodeHash_
            );
            _printContractPair("MockUnderlyingFeeToken", mockUnderlyingProxy_, mockUnderlyingImpl_);
        }

        _printContractPair("FeeToken", feeTokenProxy_, feeTokenImpl_);
        _printContractPair("SettlementChainGateway", gatewayProxy_, gatewayImpl_);
    }

    function _printComponentContracts(address factory_, bytes32 proxyInitCodeHash_) internal view {
        address paramRegProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.parameterRegistryProxySalt,
            proxyInitCodeHash_
        );
        address feeTokenProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.feeTokenProxySalt,
            proxyInitCodeHash_
        );
        address gatewayProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.gatewayProxySalt,
            proxyInitCodeHash_
        );

        console.log("\n--- COMPONENT CONTRACTS ---");

        if (_deploymentData.payerRegistryProxySalt != 0) {
            address payerRegistryProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.payerRegistryProxySalt,
                proxyInitCodeHash_
            );
            address payerRegistryImpl_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(type(PayerRegistry).creationCode, abi.encode(paramRegProxy_, feeTokenProxy_))
            );
            _printContractPair("PayerRegistry", payerRegistryProxy_, payerRegistryImpl_);
        }

        if (_deploymentData.rateRegistryProxySalt != 0) {
            address rateRegistryProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.rateRegistryProxySalt,
                proxyInitCodeHash_
            );
            address rateRegistryImpl_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(type(RateRegistry).creationCode, abi.encode(paramRegProxy_))
            );
            _printContractPair("RateRegistry", rateRegistryProxy_, rateRegistryImpl_);
        }

        if (_deploymentData.nodeRegistryProxySalt != 0) {
            address nodeRegistryProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.nodeRegistryProxySalt,
                proxyInitCodeHash_
            );
            address nodeRegistryImpl_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(type(NodeRegistry).creationCode, abi.encode(paramRegProxy_))
            );
            _printContractPair("NodeRegistry", nodeRegistryProxy_, nodeRegistryImpl_);
        }

        if (
            _deploymentData.payerReportManagerProxySalt != 0 &&
            _deploymentData.nodeRegistryProxySalt != 0 &&
            _deploymentData.payerRegistryProxySalt != 0
        ) {
            _printPayerReportManager(factory_, proxyInitCodeHash_, paramRegProxy_);
        }

        if (
            _deploymentData.distributionManagerProxySalt != 0 &&
            _deploymentData.nodeRegistryProxySalt != 0 &&
            _deploymentData.payerReportManagerProxySalt != 0 &&
            _deploymentData.payerRegistryProxySalt != 0
        ) {
            _printDistributionManager(factory_, proxyInitCodeHash_, paramRegProxy_, feeTokenProxy_);
        }

        if (_deploymentData.payerRegistryProxySalt != 0) {
            address payerRegistryProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.payerRegistryProxySalt,
                proxyInitCodeHash_
            );
            address depositSplitter_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(
                    type(DepositSplitter).creationCode,
                    abi.encode(feeTokenProxy_, payerRegistryProxy_, gatewayProxy_, _deploymentData.appChainId)
                )
            );
            console.log("DepositSplitter (no proxy):", depositSplitter_);
        }

        console.log("");
    }

    function predictAppChainAddresses() external view {
        if (_deploymentData.factory == address(0)) revert FactoryNotSet();

        address factory_ = _deploymentData.factory;

        console.log("\n=== App Chain Address Predictions ===");
        console.log("Deployer:", _deployer);
        console.log("Factory Proxy (from config):", factory_);
        console.log("");

        // Compute initializableImplementation address
        address initializableImpl_ = vm.computeCreateAddress(factory_, 1);
        bytes32 proxyInitCodeHash_ = keccak256(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(initializableImpl_))
        );

        // Compute addresses in dependency order
        address paramRegProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.parameterRegistryProxySalt,
            proxyInitCodeHash_
        );
        address factoryImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(type(Factory).creationCode, abi.encode(paramRegProxy_))
        );
        address paramRegImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(type(AppChainParameterRegistry).creationCode)
        );
        address gatewayProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.gatewayProxySalt,
            proxyInitCodeHash_
        );
        address gatewayImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(type(AppChainGateway).creationCode, abi.encode(paramRegProxy_, gatewayProxy_))
        );

        // Print BASE contracts
        console.log("--- BASE CONTRACTS ---");
        _printContractPair("Factory", factory_, factoryImpl_);
        _printContractPair("AppChainParameterRegistry", paramRegProxy_, paramRegImpl_);
        _printContractPair("AppChainGateway", gatewayProxy_, gatewayImpl_);

        // Component addresses - only compute if salts are set
        console.log("\n--- COMPONENT CONTRACTS ---");

        if (_deploymentData.groupMessageBroadcasterProxySalt != 0) {
            address groupMessageBroadcasterProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.groupMessageBroadcasterProxySalt,
                proxyInitCodeHash_
            );
            address groupMessageBroadcasterImpl_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(type(GroupMessageBroadcaster).creationCode, abi.encode(paramRegProxy_))
            );
            _printContractPair("GroupMessageBroadcaster", groupMessageBroadcasterProxy_, groupMessageBroadcasterImpl_);
        }

        if (_deploymentData.identityUpdateBroadcasterProxySalt != 0) {
            address identityUpdateBroadcasterProxy_ = _computeProxyAddress(
                factory_,
                _deployer,
                _deploymentData.identityUpdateBroadcasterProxySalt,
                proxyInitCodeHash_
            );
            address identityUpdateBroadcasterImpl_ = _computeImplementationAddress(
                factory_,
                abi.encodePacked(type(IdentityUpdateBroadcaster).creationCode, abi.encode(paramRegProxy_))
            );
            _printContractPair(
                "IdentityUpdateBroadcaster",
                identityUpdateBroadcasterProxy_,
                identityUpdateBroadcasterImpl_
            );
        }

        console.log("");
    }

    function _computeImplementationAddress(
        address factory_,
        bytes memory creationCode_
    ) internal pure returns (address) {
        bytes32 bytecodeHash_ = keccak256(creationCode_);
        return Create2.computeAddress(bytecodeHash_, bytecodeHash_, factory_);
    }

    function _computeProxyAddress(
        address factory_,
        address caller_,
        bytes32 salt_,
        bytes32 proxyInitCodeHash_
    ) internal pure returns (address) {
        bytes32 proxySalt_ = keccak256(abi.encode(caller_, salt_));
        return Create2.computeAddress(proxySalt_, proxyInitCodeHash_, factory_);
    }

    function _printPayerReportManager(
        address factory_,
        bytes32 proxyInitCodeHash_,
        address paramRegProxy_
    ) internal view {
        address nodeRegistryProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.nodeRegistryProxySalt,
            proxyInitCodeHash_
        );
        address payerRegistryProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.payerRegistryProxySalt,
            proxyInitCodeHash_
        );
        address payerReportManagerProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.payerReportManagerProxySalt,
            proxyInitCodeHash_
        );
        address payerReportManagerImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(
                type(PayerReportManager).creationCode,
                abi.encode(paramRegProxy_, nodeRegistryProxy_, payerRegistryProxy_)
            )
        );
        _printContractPair("PayerReportManager", payerReportManagerProxy_, payerReportManagerImpl_);
    }

    function _printDistributionManager(
        address factory_,
        bytes32 proxyInitCodeHash_,
        address paramRegProxy_,
        address feeTokenProxy_
    ) internal view {
        address nodeRegistryProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.nodeRegistryProxySalt,
            proxyInitCodeHash_
        );
        address payerReportManagerProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.payerReportManagerProxySalt,
            proxyInitCodeHash_
        );
        address payerRegistryProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.payerRegistryProxySalt,
            proxyInitCodeHash_
        );
        address distributionManagerProxy_ = _computeProxyAddress(
            factory_,
            _deployer,
            _deploymentData.distributionManagerProxySalt,
            proxyInitCodeHash_
        );
        address distributionManagerImpl_ = _computeImplementationAddress(
            factory_,
            abi.encodePacked(
                type(DistributionManager).creationCode,
                abi.encode(
                    paramRegProxy_,
                    nodeRegistryProxy_,
                    payerReportManagerProxy_,
                    payerRegistryProxy_,
                    feeTokenProxy_
                )
            )
        );
        _printContractPair("DistributionManager", distributionManagerProxy_, distributionManagerImpl_);
    }

    function _printContractPair(string memory name_, address proxy_, address impl_) internal pure {
        console.log(name_, ":");
        console.log("  Proxy:         ", proxy_);
        console.log("  Implementation:", impl_);
    }
}
