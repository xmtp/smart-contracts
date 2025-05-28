// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";

import { AppChainGateway } from "../../src/app-chain/AppChainGateway.sol";

library AppChainGatewayDeployer {
    error ZeroFactory();
    error ZeroParameterRegistry();
    error ZeroSettlementChainGateway();
    error ZeroImplementation();

    function deployImplementation(
        address factory_,
        address parameterRegistry_,
        address settlementChainGateway_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        if (factory_ == address(0)) revert ZeroFactory();
        if (parameterRegistry_ == address(0)) revert ZeroParameterRegistry();
        if (settlementChainGateway_ == address(0)) revert ZeroSettlementChainGateway();

        constructorArguments_ = abi.encode(parameterRegistry_, settlementChainGateway_);

        bytes memory creationCode_ = abi.encodePacked(type(AppChainGateway).creationCode, constructorArguments_);

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_
    ) internal returns (address proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_) {
        if (factory_ == address(0)) revert ZeroFactory();
        if (implementation_ == address(0)) revert ZeroImplementation();

        constructorArguments_ = abi.encode(IFactory(factory_).initializableImplementation());
        initializeCallData_ = abi.encodeWithSelector(AppChainGateway.initialize.selector);
        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }

    function getImplementation(
        address factory_,
        address parameterRegistry_,
        address settlementChainGateway_
    ) internal view returns (address implementation_) {
        bytes memory constructorArguments_ = abi.encode(parameterRegistry_, settlementChainGateway_);
        bytes memory creationCode_ = abi.encodePacked(type(AppChainGateway).creationCode, constructorArguments_);

        return IFactory(factory_).computeImplementationAddress(creationCode_);
    }

    function getProxy(address factory_, address caller_, bytes32 salt_) internal view returns (address proxy_) {
        return IFactory(factory_).computeProxyAddress(caller_, salt_);
    }
}
