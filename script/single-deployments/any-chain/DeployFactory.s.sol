// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";
import { console } from "../../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../../Deploy.s.sol";
import { FactoryDeployer } from "../../deployers/FactoryDeployer.sol";
import { Utils } from "../../utils/Utils.sol";
import { Factory } from "../../../src/any-chain/Factory.sol";
import { IFactory } from "../../../src/any-chain/interfaces/IFactory.sol";

/**
 * @title  DeployFactoryScript
 * @notice Deploys a new Factory proxy and implementation pair via the existing (old) Factory.
 * @dev    See DeployFactory.md for detailed deployment instructions.
 *         Entry points: predictAddresses(), deployContract(), verifyDeployment().
 *
 *         Unlike the base deploy (which uses CREATE / nonce-based addressing), this script deploys
 *         BOTH the implementation and proxy through the old Factory's CREATE2, giving fully
 *         deterministic addresses that do not depend on deployer nonce.
 *
 *         The `factory` field in config/<environment>.json must remain the OLD Factory address
 *         during deployment. Update it to the new address only after deployment succeeds.
 */
contract DeployFactoryScript is DeployScripts {
    error FactoryProxySaltNotSet();
    error OldFactoryNotSet();
    error NewFactoryProxyAlreadyExists();
    error ImplementationAddressMismatch(address expected, address actual);
    error ProxyAddressMismatch(address expected, address actual);
    error InitializableImplementationMismatch(address expected, address actual);
    error ParameterRegistryMismatch(address expected, address actual);
    error ChainNotRecognized();

    bytes32 internal _factoryProxySalt;

    function _readFactoryProxySalt() internal view returns (bytes32 salt_) {
        string memory json_ = vm.readFile(string.concat("config/", _environment, ".json"));
        salt_ = Utils.stringToBytes32(stdJson.readString(json_, ".factoryProxySalt"));

        if (salt_ == 0) revert FactoryProxySaltNotSet();
    }

    /// @notice Step 1: Predict deterministic addresses for implementation, proxy, and initializableImplementation.
    function predictAddresses() external view {
        if (_deploymentData.factory == address(0)) revert OldFactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        bytes32 salt_ = _readFactoryProxySalt();

        address computedImplementation_ = FactoryDeployer.getImplementationViaFactory(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        address computedProxy_ = IFactory(_deploymentData.factory).computeProxyAddress(_deployer, salt_);

        address computedInitializable_ = vm.computeCreateAddress(computedProxy_, 1);

        console.log("Old Factory: %s", _deploymentData.factory);
        console.log("Parameter Registry: %s", _deploymentData.parameterRegistryProxy);
        console.log("Factory Proxy Salt: %s", Utils.bytes32ToString(salt_));
        console.log("");
        console.log("New Factory Predicted Addresses:");
        console.log("  factoryImplementation: %s", computedImplementation_);
        console.log("  factory:               %s", computedProxy_);
        console.log("  initializableImplementation: %s", computedInitializable_);

        if (computedImplementation_.code.length > 0) {
            console.log("");
            console.log("NOTE: Code already exists at predicted implementation address.");
            console.log("      This is expected if the Factory bytecode has not changed.");
        }

        if (computedProxy_.code.length > 0) {
            console.log("");
            console.log("WARNING: Code already exists at predicted proxy address!");
            console.log("         Choose a different factoryProxySalt in config JSON.");
        }
    }

    /// @notice Step 2: Deploy Factory implementation and proxy via the old Factory.
    function deployContract() external {
        if (_deploymentData.factory == address(0)) revert OldFactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        _factoryProxySalt = _readFactoryProxySalt();

        address expectedImplementation_ = FactoryDeployer.getImplementationViaFactory(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        address expectedProxy_ = IFactory(_deploymentData.factory).computeProxyAddress(_deployer, _factoryProxySalt);

        if (expectedProxy_.code.length > 0) revert NewFactoryProxyAlreadyExists();

        address expectedInitializable_ = vm.computeCreateAddress(expectedProxy_, 1);

        console.log("Deploying new Factory via old Factory at %s", _deploymentData.factory);

        vm.startBroadcast(_deployerPrivateKey);

        // Deploy implementation via old Factory (CREATE2, idempotent if bytecode matches)
        address newImplementation_;
        if (expectedImplementation_.code.length == 0) {
            bytes memory constructorArgs_ = abi.encode(_deploymentData.parameterRegistryProxy);
            bytes memory creationCode_ = abi.encodePacked(type(Factory).creationCode, constructorArgs_);
            newImplementation_ = IFactory(_deploymentData.factory).deployImplementation(creationCode_);
        } else {
            newImplementation_ = expectedImplementation_;
            console.log("Implementation already deployed (bytecode unchanged): %s", newImplementation_);
        }

        // Deploy proxy via old Factory (CREATE2 + initialize in one atomic call)
        bytes memory initCallData_ = abi.encodeWithSelector(Factory.initialize.selector);
        address newProxy_ = IFactory(_deploymentData.factory).deployProxy(
            newImplementation_,
            _factoryProxySalt,
            initCallData_
        );

        vm.stopBroadcast();

        // Validate addresses match predictions
        if (newImplementation_ != expectedImplementation_) {
            revert ImplementationAddressMismatch(expectedImplementation_, newImplementation_);
        }

        if (newProxy_ != expectedProxy_) {
            revert ProxyAddressMismatch(expectedProxy_, newProxy_);
        }

        address actualInitializable_ = IFactory(newProxy_).initializableImplementation();
        if (actualInitializable_ != expectedInitializable_) {
            revert InitializableImplementationMismatch(expectedInitializable_, actualInitializable_);
        }

        // Validate runtime state
        address actualParamRegistry_ = IFactory(newProxy_).parameterRegistry();
        if (actualParamRegistry_ != _deploymentData.parameterRegistryProxy) {
            revert ParameterRegistryMismatch(_deploymentData.parameterRegistryProxy, actualParamRegistry_);
        }

        console.log("Factory Implementation: %s", newImplementation_);
        console.log("Factory Proxy:          %s", newProxy_);
        console.log("Factory Name:           %s", IFactory(newProxy_).contractName());
        console.log("Factory Version:        %s", IFactory(newProxy_).version());
        console.log("Parameter Registry:     %s", actualParamRegistry_);
        console.log("Initializable Impl:     %s", actualInitializable_);

        _writeFactoryToEnvironment(newProxy_);
    }

    /// @notice Step 3: Verify the deployed Factory matches expectations (read-only, no broadcast).
    function verifyDeployment() external view {
        if (_deploymentData.factory == address(0)) revert OldFactoryNotSet();
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        bytes32 salt_ = _readFactoryProxySalt();

        address expectedImplementation_ = FactoryDeployer.getImplementationViaFactory(
            _deploymentData.factory,
            _deploymentData.parameterRegistryProxy
        );

        address expectedProxy_ = IFactory(_deploymentData.factory).computeProxyAddress(_deployer, salt_);
        address expectedInitializable_ = vm.computeCreateAddress(expectedProxy_, 1);

        console.log("Verifying Factory deployment...");
        console.log("Expected Implementation: %s", expectedImplementation_);
        console.log("Expected Proxy:          %s", expectedProxy_);
        console.log("Expected Initializable:  %s", expectedInitializable_);

        if (expectedProxy_.code.length == 0) {
            console.log("FAIL: No code at expected proxy address. Factory not deployed.");
            return;
        }

        if (expectedImplementation_.code.length == 0) {
            console.log("FAIL: No code at expected implementation address.");
            return;
        }

        IFactory newFactory_ = IFactory(expectedProxy_);

        console.log("");
        console.log("On-chain state:");
        console.log("  contractName:              %s", newFactory_.contractName());
        console.log("  version:                   %s", newFactory_.version());
        console.log("  parameterRegistry:         %s", newFactory_.parameterRegistry());
        console.log("  initializableImplementation: %s", newFactory_.initializableImplementation());
        console.log("  paused:                    %s", newFactory_.paused() ? "true" : "false");

        bool allGood_ = true;

        if (newFactory_.parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            console.log("FAIL: parameterRegistry mismatch");
            allGood_ = false;
        }

        if (newFactory_.initializableImplementation() != expectedInitializable_) {
            console.log("FAIL: initializableImplementation mismatch");
            allGood_ = false;
        }

        if (newFactory_.initializableImplementation() == address(0)) {
            console.log("FAIL: initializableImplementation is zero (not initialized)");
            allGood_ = false;
        }

        if (allGood_) {
            console.log("");
            console.log("All checks passed.");
        }
    }

    function _writeFactoryToEnvironment(address newFactory_) internal {
        string memory filePath_ = string.concat("environments/", _environment, ".json");

        string memory key_;
        if (block.chainid == _deploymentData.settlementChainId) {
            key_ = "settlementChainFactory";
        } else if (block.chainid == _deploymentData.appChainId) {
            key_ = "appChainFactory";
        } else {
            revert ChainNotRecognized();
        }

        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            vm.serializeJson("root", vm.readFile(filePath_));
            string memory json_ = vm.serializeAddress("root", key_, newFactory_);
            vm.writeJson(json_, filePath_);
            console.log("Updated %s in %s", key_, filePath_);
        } else {
            console.log("Not broadcasted. No writes to environment JSON.");
            console.log("Would update %s = %s in %s", key_, vm.toString(newFactory_), filePath_);
        }
    }
}
