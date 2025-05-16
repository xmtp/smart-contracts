// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";

import { DistributionManager } from "../../src/settlement-chain/DistributionManager.sol";

library DistributionManagerDeployer {
    error ZeroFactory();
    error ZeroParameterRegistry();
    error ZeroNodeRegistry();
    error ZeroPayerReportManager();
    error ZeroPayerRegistry();
    error ZeroToken();
    error ZeroImplementation();

    function deployImplementation(
        address factory_,
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address token_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        require(factory_ != address(0), ZeroFactory());
        require(parameterRegistry_ != address(0), ZeroParameterRegistry());
        require(nodeRegistry_ != address(0), ZeroNodeRegistry());
        require(payerReportManager_ != address(0), ZeroPayerReportManager());
        require(payerRegistry_ != address(0), ZeroPayerRegistry());
        require(token_ != address(0), ZeroToken());

        constructorArguments_ = abi.encode(
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            token_
        );

        bytes memory creationCode_ = abi.encodePacked(type(DistributionManager).creationCode, constructorArguments_);

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
        initializeCallData_ = abi.encodeWithSelector(DistributionManager.initialize.selector);
        proxy_ = IFactory(factory_).deployProxy(implementation_, salt_, initializeCallData_);
    }

    function getImplementation(
        address factory_,
        address parameterRegistry_,
        address nodeRegistry_,
        address payerReportManager_,
        address payerRegistry_,
        address token_
    ) internal view returns (address implementation_) {
        bytes memory constructorArguments_ = abi.encode(
            parameterRegistry_,
            nodeRegistry_,
            payerReportManager_,
            payerRegistry_,
            token_
        );
        bytes memory creationCode_ = abi.encodePacked(type(DistributionManager).creationCode, constructorArguments_);

        return IFactory(factory_).computeImplementationAddress(creationCode_);
    }

    function getProxy(address factory_, address caller_, bytes32 salt_) internal view returns (address proxy_) {
        return IFactory(factory_).computeProxyAddress(caller_, salt_);
    }
}
