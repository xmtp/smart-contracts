// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "../../lib/forge-std/src/Vm.sol";

library Utils {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant EIP1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function generatePayload(uint256 length) internal pure returns (bytes memory payload) {
        payload = new bytes(length);

        for (uint256 i; i < payload.length; ++i) {
            payload[i] = bytes1(uint8(i % 256));
        }
    }

    /// @dev This is NOT cryptographically secure. Just good enough for testing.
    function genRandomInt(uint256 min, uint256 max) internal view returns (uint256 output) {
        return
            min +
            (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, block.number, msg.sender))) %
                (max - min + 1));
    }

    function genBytes(uint32 length) internal pure returns (bytes memory message) {
        message = new bytes(length);

        for (uint256 i; i < length; ++i) {
            message[i] = bytes1(uint8(i % 256));
        }
    }

    function genString(uint32 length) internal pure returns (string memory output) {
        return string(genBytes(length));
    }

    function expectAndMockParameterRegistryGet(address parameterRegistry_, bytes memory key_, bytes32 value_) internal {
        expectAndMockCall(parameterRegistry_, abi.encodeWithSignature("get(bytes)", key_), abi.encode(value_));
    }

    function expectAndMockCall(address callee_, bytes memory data_, bytes memory returnData_) internal {
        VM.expectCall(callee_, data_);
        VM.mockCall(callee_, data_, returnData_);
    }

    function getImplementationFromSlot(address proxy_) internal view returns (address implementation_) {
        // Retrieve the implementation address directly from the proxy storage.
        return address(uint160(uint256(VM.load(proxy_, EIP1967_IMPLEMENTATION_SLOT))));
    }
}
