// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../../lib/forge-std/src/Script.sol";

import { Factory } from "../../src/any-chain/Factory.sol";

library FactoryDeployer {
    function deploy() internal returns (address factory_) {
        return address(new Factory());
    }
}
