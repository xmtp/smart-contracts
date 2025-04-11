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
    error ExpectedFactoryNotSet();
    error UnexpectedFactory();

    uint256 internal _privateKey;
    address internal _deployer;

    function setUp() external {
        _privateKey = vm.envUint("PRIVATE_KEY");

        require(_privateKey != 0, PrivateKeyNotSet());

        _deployer = vm.addr(_privateKey);
    }

    function run() external {
        deploy();
    }

    function deploy() public returns (address factory_) {
        require(Environment.EXPECTED_FACTORY != address(0), ExpectedFactoryNotSet());

        vm.startBroadcast(_privateKey);

        factory_ = address(FactoryDeployer.deploy());

        require(factory_ == Environment.EXPECTED_FACTORY, UnexpectedFactory());

        vm.stopBroadcast();

        string memory json_ = Utils.buildFactoryJson(_deployer, factory_);

        Utils.writeOutput(json_, string.concat(Environment.FACTORY_OUTPUT_JSON, "_", vm.toString(block.chainid)));
    }
}
