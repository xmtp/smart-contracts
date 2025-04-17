// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Create2 } from "../../lib/oz/contracts/utils/Create2.sol";

import { IInitializable } from "./interfaces/IInitializable.sol";
import { IFactory } from "./interfaces/IFactory.sol";

import { Initializable } from "./Initializable.sol";
import { Proxy } from "./Proxy.sol";

/**
 * @title  Factory contract that deterministically deploys implementations and proxies.
 * @notice This contract is used to deploy implementations and proxies deterministically, using `create2`, and is to
 *         only be deployed once on each chain. Implementations deployed use their own bytecode hash as their salt, so
 *         a unique bytecode (including constructor arguments) will have only one possible address. Proxies deployed use
 *         the sender's address combined with a salt of the sender's choosing as a final salt, and the constructor
 *         arguments are always the same (i.e. the "initializable implementation"), so the their address has only 2
 *         degrees of freedom. This is helpful for ensuring the address of a future/planned contract is constant, while
 *         the implementation is not yet finalized or deployed.
 */
contract Factory is IFactory {
    /* ============ Constants/Immutables ============ */

    /// @inheritdoc IFactory
    address public immutable initializableImplementation;

    /* ============ Constructor ============ */

    /**
     * @notice Constructor that deploys the initializable implementation.
     */
    constructor() {
        emit InitializableImplementationDeployed(initializableImplementation = address(new Initializable()));
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IFactory
    function deployImplementation(bytes calldata bytecode_) external returns (address implementation_) {
        require(bytecode_.length > 0, EmptyBytecode());

        bytes32 bytecodeHash_ = keccak256(bytecode_);

        // NOTE: Since an implementation is expected to be proxied, it can be a singleton, so its address can depend
        //       entirely on its bytecode, thus a unique bytecode will have only one possible address.
        emit ImplementationDeployed(implementation_ = _create2(bytecode_, bytecodeHash_), bytecodeHash_);
    }

    /// @inheritdoc IFactory
    function deployProxy(
        address implementation_,
        bytes32 salt_,
        bytes calldata initializeCallData_
    ) external returns (address proxy_) {
        // Append the initializable implementation address as a constructor argument to the proxy deploy code, and use
        // the sender's address combined with their chosen salt as the final salt.
        proxy_ = _create2(
            abi.encodePacked(type(Proxy).creationCode, abi.encode(initializableImplementation)),
            keccak256(abi.encode(msg.sender, salt_))
        );

        emit ProxyDeployed(proxy_, implementation_, msg.sender, salt_, initializeCallData_);

        // Initialize the proxy, which will set its intended implementation slot and initialize it.
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

        require(_isNotZero(deployed_), DeployFailed());
    }

    /* ============ Internal View/Pure Functions ============ */

    function _isNotZero(address input_) internal pure returns (bool isNotZero_) {
        return input_ != address(0);
    }
}
