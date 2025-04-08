// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import { CREATE3 } from "../../lib/solady/src/utils/CREATE3.sol";

import { ICREATE3Factory } from "./interfaces/ICREATE3Factory.sol";

/**
 * @title Factory for deploying contracts to deterministic addresses via CREATE3
 * @notice Enables deploying contracts using CREATE3. Each deployer (msg.sender) has
 * its own namespace for deployed addresses.
 */
contract CREATE3Factory is ICREATE3Factory {
    /// @inheritdoc	ICREATE3Factory
    function deploy(bytes32 salt, bytes memory initCode) external payable returns (address deployed) {
        return CREATE3.deployDeterministic(msg.value, initCode, keccak256(abi.encodePacked(msg.sender, salt)));
    }

    /// @inheritdoc	ICREATE3Factory
    function predictDeterministicAddress(bytes32 salt, address deployer) external view returns (address predicted) {
        return CREATE3.predictDeterministicAddress(keccak256(abi.encodePacked(deployer, salt)));
    }
}
