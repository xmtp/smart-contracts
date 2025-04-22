// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Create2 } from "../../lib/oz/contracts/utils/Create2.sol";

import { IInitializable } from "./interfaces/IInitializable.sol";
import { IFactory } from "./interfaces/IFactory.sol";

import { Initializable } from "./Initializable.sol";
import { Proxy } from "./Proxy.sol";

contract Factory is IFactory {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IFactory
    address public immutable initializableImplementation;

    /* ============ Constructor ============ */

    constructor() {
        emit InitializableImplementationDeployed(initializableImplementation = address(new Initializable()));
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IFactory
    function deployImplementation(bytes calldata bytecode_) external returns (address implementation_) {
        require(bytecode_.length > 0, EmptyBytecode());

        // NOTE: Since an implementation is expected to be proxied, it's address can depend entirely on its bytecode, so
        //       a unique bytecode will have only one possible address.
        emit ImplementationDeployed(implementation_ = _create2(bytecode_, keccak256(bytecode_)));
    }

    /// @inheritdoc IFactory
    function deployProxy(
        address implementation_,
        bytes32 salt_,
        bytes calldata initializeCallData_
    ) external returns (address proxy_) {
        proxy_ = _create2(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(initializableImplementation)),
            keccak256(abi.encode(msg.sender, salt_))
        );

        emit ProxyDeployed(proxy_, implementation_, msg.sender, salt_, initializeCallData_);

        // Initialize the proxy, which will set its implementation slot and delegatecall some initialization code.
        IInitializable(proxy_).initialize(implementation_, initializeCallData_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IFactory
    function computeImplementationAddress(bytes calldata bytecode_) external view returns (address implementation_) {
        bytes32 bytecodeHash_ = keccak256(bytecode_);
        return Create2.computeAddress(bytecodeHash_, bytecodeHash_);
    }

    /// @inheritdoc IFactory
    function computeProxyAddress(address caller_, bytes32 salt_) external view returns (address proxy_) {
        bytes memory initCode_ = abi.encodePacked(type(Proxy).creationCode, abi.encode(initializableImplementation));
        return Create2.computeAddress(keccak256(abi.encode(caller_, salt_)), keccak256(initCode_));
    }

    /* ============ Internal Interactive Functions ============ */

    /// @dev Creates a contract via `create2` and reverts if the deployment fails.
    function _create2(bytes memory bytecode_, bytes32 salt_) internal returns (address deployed_) {
        // slither-disable-next-line assembly
        assembly {
            deployed_ := create2(0, add(bytecode_, 0x20), mload(bytecode_), salt_)
        }

        require(deployed_ != address(0), DeployFailed());
    }
}
