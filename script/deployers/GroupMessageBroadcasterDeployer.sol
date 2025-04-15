// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IPayloadBroadcaster } from "../../src/abstract/interfaces/IPayloadBroadcaster.sol";

import { GroupMessageBroadcaster } from "../../src/app-chain/GroupMessageBroadcaster.sol";

library GroupMessageBroadcasterDeployer {
    error ZeroFactory();
    error ZeroParameterRegistry();
    error ZeroImplementation();

    function deployImplementation(
        address factory_,
        address parameterRegistry_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());
        require(parameterRegistry_ != address(0), ZeroParameterRegistry());

        constructorArguments_ = abi.encode(parameterRegistry_);

        bytes memory creationCode_ = abi.encodePacked(
            type(GroupMessageBroadcaster).creationCode,
            constructorArguments_
        );

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_
    ) internal returns (address proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_) {
        require(factory_ != address(0), ZeroFactory());
        require(implementation_ != address(0), ZeroImplementation());

        constructorArguments_ = abi.encode(IFactory(factory_).initializableImplementation());
        initializeCallData_ = abi.encodeWithSelector(IPayloadBroadcaster.initialize.selector);
        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }

    function getImplementation(
        address factory_,
        address parameterRegistry_
    ) internal view returns (address implementation_) {
        bytes memory constructorArguments_ = abi.encode(parameterRegistry_);

        bytes memory creationCode_ = abi.encodePacked(
            type(GroupMessageBroadcaster).creationCode,
            constructorArguments_
        );

        return IFactory(factory_).computeImplementationAddress(creationCode_);
    }

    function getProxy(address factory_, address caller_, bytes32 salt_) internal view returns (address proxy_) {
        return IFactory(factory_).computeProxyAddress(caller_, salt_);
    }
}
