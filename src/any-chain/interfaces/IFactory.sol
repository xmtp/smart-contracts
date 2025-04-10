// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFactory {
    event InitializableImplementationDeployed(address indexed implementation);

    event ProxyDeployed(
        address indexed proxy,
        address indexed implementation,
        address indexed sender,
        bytes32 salt,
        bytes initializeCallData
    );

    event ImplementationDeployed(address indexed implementation);

    error EmptyBytecode();

    error DeployFailed();

    function deployImplementation(bytes memory bytecode_) external returns (address implementation_);

    function deployProxy(
        address implementation_,
        bytes32 salt_,
        bytes calldata initializeCallData_
    ) external returns (address proxy_);

    function initializableImplementation() external view returns (address initializableImplementation_);

    function computeImplementationAddress(bytes memory bytecode_) external view returns (address implementation_);

    function computeProxyAddress(address caller_, bytes32 salt_) external view returns (address proxy_);
}
