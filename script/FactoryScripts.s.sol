// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FactoryDeployer } from "./deployers/FactoryDeployer.sol";

import { ScriptBase } from "./ScriptBase.s.sol";
import { Utils } from "./utils/Utils.sol";

contract FactoryScripts is ScriptBase {
    error FactoryNotSet();
    error UnexpectedFactory();

    function deploy() public returns (address factory_) {
        require(_deploymentData.factory != address(0), FactoryNotSet());

        vm.startBroadcast(_privateKey);

        factory_ = FactoryDeployer.deploy();

        require(factory_ == _deploymentData.factory, UnexpectedFactory());

        vm.stopBroadcast();

        string memory json_ = Utils.buildFactoryJson(_deployer, factory_);

        Utils.writeOutput(json_, string.concat(Utils.FACTORY_OUTPUT_JSON, "_", vm.toString(block.chainid)));
    }
}
