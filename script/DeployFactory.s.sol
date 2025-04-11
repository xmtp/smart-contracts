// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { Factory } from "../src/any-chain/Factory.sol";

import { Utils } from "./utils/Utils.sol";
import { Environment } from "./utils/Environment.sol";

library FactoryDeployer {
    function deploy() internal returns (Factory factory_) {
        return new Factory();
    }
}

contract DeployFactory is Script {
    error PrivateKeyNotSet();
    error FactoryDeploymentFailed();

    function run() external {
        uint256 privateKey_ = vm.envUint("PRIVATE_KEY");

        require(privateKey_ != 0, PrivateKeyNotSet());

        address deployer_ = vm.addr(privateKey_);

        vm.startBroadcast(deployer_);

        address factory_ = address(FactoryDeployer.deploy());

        vm.stopBroadcast();

        require(factory_ != address(0), FactoryDeploymentFailed());

        _serializeDeploymentData(vm.addr(privateKey_), factory_);
    }

    function _serializeDeploymentData(address deployer_, address factory_) internal {
        string memory parentObject_ = "parent object";
        string memory addresses_ = "addresses";
        string memory constructorArgs_ = "constructorArgs";

        string memory addressesOutput_;
        addressesOutput_ = vm.serializeAddress(addresses_, "deployer", deployer_);
        addressesOutput_ = vm.serializeAddress(addresses_, "implementation", factory_);

        string memory constructorArgsOutput_;

        string memory finalJson_;
        finalJson_ = vm.serializeString(parentObject_, addresses_, addressesOutput_);
        finalJson_ = vm.serializeString(parentObject_, constructorArgs_, constructorArgsOutput_);
        finalJson_ = vm.serializeUint(parentObject_, "deploymentBlock", block.number);

        Utils.writeOutput(finalJson_, Environment.XMTP_FACTORY_OUTPUT_JSON);
    }
}
