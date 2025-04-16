// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";

import { NodeRegistry } from "../../src/settlement-chain/NodeRegistry.sol";

library NodeRegistryDeployer {
    error ZeroFactory();
    error ZeroInitialAdmin();

    function deployImplementation(
        address factory_,
        address initialAdmin_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());
        require(initialAdmin_ != address(0), ZeroInitialAdmin());

        constructorArguments_ = abi.encode(initialAdmin_);

        bytes memory creationCode_ = abi.encodePacked(type(NodeRegistry).creationCode, constructorArguments_);

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function getImplementation(
        address factory_,
        address initialAdmin_
    ) internal view returns (address implementation_) {
        bytes memory constructorArguments_ = abi.encode(initialAdmin_);
        bytes memory creationCode_ = abi.encodePacked(type(NodeRegistry).creationCode, constructorArguments_);

        return IFactory(factory_).computeImplementationAddress(creationCode_);
    }
}
