// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Factory } from "../../src/any-chain/Factory.sol";
import { Proxy } from "../../src/any-chain/Proxy.sol";

library FactoryDeployer {
    error ZeroImplementation();
    error ZeroParameterRegistry();

    function deployImplementation(
        address parameterRegistry_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        if (parameterRegistry_ == address(0)) revert ZeroParameterRegistry();

        implementation_ = address(new Factory(parameterRegistry_));
        constructorArguments_ = abi.encode(parameterRegistry_);
    }

    function deployProxy(
        address implementation_
    ) internal returns (address proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_) {
        if (implementation_ == address(0)) revert ZeroImplementation();

        proxy_ = address(new Proxy(implementation_));
        constructorArguments_ = abi.encode(implementation_);
        initializeCallData_ = abi.encodeWithSelector(Factory.initialize.selector);
    }
}
