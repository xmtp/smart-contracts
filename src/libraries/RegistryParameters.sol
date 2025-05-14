// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IParameterRegistryLike } from "./interfaces/External.sol";
import { IRegistryParametersErrors } from "./interfaces/IRegistryParametersErrors.sol";

/**
 * @title  Library for interacting with a parameter registry.
 * @notice Exposes getters, setters, and parsers for parameters stored in a parameter registry.
 */
library RegistryParameters {
    /* ============ Interactive Functions ============ */

    function setRegistryParameter(address parameterRegistry_, bytes memory key_, bytes32 value_) internal {
        IParameterRegistryLike(parameterRegistry_).set(key_, value_);
    }

    /* ============ View/Pure Functions ============ */

    function getRegistryParameters(
        address parameterRegistry_,
        bytes[] memory keys_
    ) internal view returns (bytes32[] memory value_) {
        return IParameterRegistryLike(parameterRegistry_).get(keys_);
    }

    function getRegistryParameter(
        address parameterRegistry_,
        bytes memory key_
    ) internal view returns (bytes32 value_) {
        return IParameterRegistryLike(parameterRegistry_).get(key_);
    }

    function getAddressParameter(
        address parameterRegistry_,
        bytes memory key_
    ) internal view returns (address output_) {
        return getAddressFromRawParameter(getRegistryParameter(parameterRegistry_, key_));
    }

    function getBoolParameter(address parameterRegistry_, bytes memory key_) internal view returns (bool output_) {
        uint256 parameter_ = uint256(getRegistryParameter(parameterRegistry_, key_));

        if (parameter_ > 1) revert IRegistryParametersErrors.ParameterOutOfTypeBounds();

        return parameter_ != 0;
    }

    function getUint8Parameter(address parameterRegistry_, bytes memory key_) internal view returns (uint8 output_) {
        uint256 parameter_ = uint256(getRegistryParameter(parameterRegistry_, key_));

        if (parameter_ > type(uint8).max) revert IRegistryParametersErrors.ParameterOutOfTypeBounds();

        return uint8(parameter_);
    }

    function getUint32Parameter(address parameterRegistry_, bytes memory key_) internal view returns (uint32 output_) {
        uint256 parameter_ = uint256(getRegistryParameter(parameterRegistry_, key_));

        if (parameter_ > type(uint32).max) revert IRegistryParametersErrors.ParameterOutOfTypeBounds();

        return uint32(parameter_);
    }

    function getUint64Parameter(address parameterRegistry_, bytes memory key_) internal view returns (uint64 output_) {
        uint256 parameter_ = uint256(getRegistryParameter(parameterRegistry_, key_));

        if (parameter_ > type(uint64).max) revert IRegistryParametersErrors.ParameterOutOfTypeBounds();

        return uint64(parameter_);
    }

    function getUint96Parameter(address parameterRegistry_, bytes memory key_) internal view returns (uint96 output_) {
        uint256 parameter_ = uint256(getRegistryParameter(parameterRegistry_, key_));

        if (parameter_ > type(uint96).max) revert IRegistryParametersErrors.ParameterOutOfTypeBounds();

        return uint96(parameter_);
    }

    function getAddressFromRawParameter(bytes32 parameter_) internal pure returns (address output_) {
        if (uint256(parameter_) > type(uint160).max) revert IRegistryParametersErrors.ParameterOutOfTypeBounds();

        return address(uint160(uint256(parameter_)));
    }
}
