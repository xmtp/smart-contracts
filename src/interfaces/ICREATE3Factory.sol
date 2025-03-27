// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title  ICREATE3Factory
 * @notice This interface defines a CREATE3Factory that can be used to deploy contracts to deterministic addresses.
 */
interface ICREATE3Factory {
    /**
     * @notice Deploys a contract using CREATE3.
     * @dev The provided salt is hashed with the deployer's address (msg.sender) to generate the final salt.
     *      The deployed contract can be funded, msg.value is forwarded to the deployed contract.
     * @param salt The salt for determining the deployed contract's address.
     * @param initCode The creation code of the contract to deploy.
     * @return deployed The address of the deployed contract.
     */
    function deploy(bytes32 salt, bytes memory initCode) external payable returns (address deployed);

    /**
     * @notice Predicts the address of a deployed contract.
     * @param salt The salt for determining the deployed contract's address.
     * @param deployer The address of the deployer.
     * @return predicted The address of the contract that will be deployed.
     */
    function predictDeterministicAddress(bytes32 salt, address deployer) external view returns (address predicted);
}
