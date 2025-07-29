// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFactory } from "../../src/any-chain/interfaces/IFactory.sol";

import { DepositSplitter } from "../../src/settlement-chain/DepositSplitter.sol";

library DepositSplitterDeployer {
    error ZeroFactory();
    error ZeroFeeToken();
    error ZeroPayerRegistry();
    error ZeroSettlementChainGateway();
    error ZeroAppChainId();

    function deployImplementation(
        address factory_,
        address feeToken_,
        address payerRegistry_,
        address settlementChainGateway_,
        uint256 appChainId_
    ) internal returns (address implementation_, bytes memory constructorArguments_) {
        if (factory_ == address(0)) revert ZeroFactory();
        if (feeToken_ == address(0)) revert ZeroFeeToken();
        if (payerRegistry_ == address(0)) revert ZeroPayerRegistry();
        if (settlementChainGateway_ == address(0)) revert ZeroSettlementChainGateway();
        if (appChainId_ == 0) revert ZeroAppChainId();

        constructorArguments_ = abi.encode(feeToken_, payerRegistry_, settlementChainGateway_, appChainId_);

        bytes memory creationCode_ = abi.encodePacked(type(DepositSplitter).creationCode, constructorArguments_);

        implementation_ = IFactory(factory_).deployImplementation(creationCode_);
    }

    function getImplementation(
        address factory_,
        address feeToken_,
        address payerRegistry_,
        address settlementChainGateway_,
        uint256 appChainId_
    ) internal view returns (address implementation_) {
        bytes memory constructorArguments_ = abi.encode(
            feeToken_,
            payerRegistry_,
            settlementChainGateway_,
            appChainId_
        );
        bytes memory creationCode_ = abi.encodePacked(type(DepositSplitter).creationCode, constructorArguments_);

        return IFactory(factory_).computeImplementationAddress(creationCode_);
    }
}
