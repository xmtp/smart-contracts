// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";
import { IParameterRegistry } from "../../src/abstract/interfaces/IParameterRegistry.sol";

import { SettlementChainParameterRegistry } from "../../src/settlement-chain/SettlementChainParameterRegistry.sol";

library SettlementChainParameterRegistryDeployer {
    error ZeroFactory();
    error ZeroImplementation();

    function deployImplementation(
        address factory_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());

        constructorArguments_ = "";

        bytes memory creationCode_ = abi.encodePacked(
            type(SettlementChainParameterRegistry).creationCode,
            constructorArguments_
        );

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function deployProxy(
        address factory_,
        address implementation_,
        bytes32 salt_,
        address[] memory admins_
    ) internal returns (address proxy_, bytes memory constructorArguments_, bytes memory initializeCallData_) {
        require(factory_ != address(0), ZeroFactory());
        require(implementation_ != address(0), ZeroImplementation());

        constructorArguments_ = abi.encode(IFactory(factory_).initializableImplementation());
        initializeCallData_ = abi.encodeCall(IParameterRegistry.initialize, (admins_));

        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }

    function getImplementation(address factory_) internal view returns (address implementation_) {
        return
            IFactory(factory_).computeImplementationAddress(
                abi.encodePacked(type(SettlementChainParameterRegistry).creationCode)
            );
    }

    function getProxy(address factory_, address caller_, bytes32 salt_) internal view returns (address proxy_) {
        return IFactory(factory_).computeProxyAddress(caller_, salt_);
    }
}
