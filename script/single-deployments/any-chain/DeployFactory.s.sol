// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { stdJson } from "../../../lib/forge-std/src/StdJson.sol";
import { console } from "../../../lib/forge-std/src/console.sol";
import { VmSafe } from "../../../lib/forge-std/src/Vm.sol";
import { DeployScripts } from "../../Deploy.s.sol";
import { FactoryDeployer } from "../../deployers/FactoryDeployer.sol";
import { Factory } from "../../../src/any-chain/Factory.sol";
import { IFactory } from "../../../src/any-chain/interfaces/IFactory.sol";

/**
 * @title  DeployFactoryScript
 * @notice Deploys a new Factory proxy and implementation via direct CREATE.
 * @dev    See DeployFactory.md for detailed deployment instructions.
 *         Entry points: deployContract(), verifyDeployment().
 *
 *         No other contract stores the Factory address as a runtime dependency, so deterministic
 *         addressing is not required. The new Factory address is written to
 *         environments/<env>.json and should be updated in config/<env>.json afterward.
 */
contract DeployFactoryScript is DeployScripts {
    error ParameterRegistryMismatch(address expected, address actual);
    error ChainNotRecognized();
    error FactoryNotDeployed();

    /// @notice Step 1: Deploy a new Factory implementation, proxy, and initialize it.
    function deployContract() external {
        if (_deploymentData.parameterRegistryProxy == address(0)) revert ParameterRegistryProxyNotSet();

        console.log("Deploying new Factory...");
        console.log("Parameter Registry: %s", _deploymentData.parameterRegistryProxy);

        vm.startBroadcast(_deployerPrivateKey);

        (address implementation_, ) = FactoryDeployer.deployImplementation(_deploymentData.parameterRegistryProxy);

        (address proxy_, , ) = FactoryDeployer.deployProxy(implementation_);

        IFactory(proxy_).initialize();

        vm.stopBroadcast();

        address actualParamRegistry_ = IFactory(proxy_).parameterRegistry();
        if (actualParamRegistry_ != _deploymentData.parameterRegistryProxy) {
            revert ParameterRegistryMismatch(_deploymentData.parameterRegistryProxy, actualParamRegistry_);
        }

        address initializableImpl_ = IFactory(proxy_).initializableImplementation();
        if (initializableImpl_ == address(0)) revert FactoryNotDeployed();

        console.log("");
        console.log("Factory deployed successfully:");
        console.log("  Implementation:               %s", implementation_);
        console.log("  Proxy:                        %s", proxy_);
        console.log("  Name:                         %s", IFactory(proxy_).contractName());
        console.log("  Version:                      %s", IFactory(proxy_).version());
        console.log("  Parameter Registry:           %s", actualParamRegistry_);
        console.log("  Initializable Implementation: %s", initializableImpl_);

        _writeFactoryToEnvironment(proxy_);
    }

    /// @notice Step 2: Verify a deployed Factory from environments JSON (read-only, no broadcast).
    function verifyDeployment() external view {
        address factory_ = _readFactoryFromEnvironment();

        console.log("Verifying Factory at %s ...", factory_);

        if (factory_.code.length == 0) {
            console.log("FAIL: No code at factory address.");
            return;
        }

        IFactory newFactory_ = IFactory(factory_);

        console.log("");
        console.log("On-chain state:");
        console.log("  contractName:                 %s", newFactory_.contractName());
        console.log("  version:                      %s", newFactory_.version());
        console.log("  parameterRegistry:            %s", newFactory_.parameterRegistry());
        console.log("  initializableImplementation:  %s", newFactory_.initializableImplementation());
        console.log("  paused:                       %s", newFactory_.paused() ? "true" : "false");

        bool allGood_ = true;

        if (newFactory_.parameterRegistry() != _deploymentData.parameterRegistryProxy) {
            console.log("FAIL: parameterRegistry mismatch");
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

    function _readFactoryFromEnvironment() internal view returns (address factory_) {
        string memory filePath_ = string.concat("environments/", _environment, ".json");
        string memory json_ = vm.readFile(filePath_);

        string memory key_;
        if (block.chainid == _deploymentData.settlementChainId) {
            key_ = ".settlementChainFactory";
        } else if (block.chainid == _deploymentData.appChainId) {
            key_ = ".appChainFactory";
        } else {
            revert ChainNotRecognized();
        }

        factory_ = stdJson.readAddress(json_, key_);
        if (factory_ == address(0)) revert FactoryNotDeployed();
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
