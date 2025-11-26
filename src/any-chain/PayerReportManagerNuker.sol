// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1967} from "../abstract/interfaces/IERC1967.sol";

contract PayerReportManagerNukingMigrator {
    /// @dev EIP-1967 impl slot
    bytes32 private constant _IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev MUST match PayerReportManager's constant exactly
    bytes32 internal constant _PAYER_REPORT_MANAGER_STORAGE_LOCATION =
    0x26b057ee8e4d60685198828fdf1c618ab8e36b0ab85f54a47b18319f6f718e00;

    fallback() external {
        // Runs in proxy storage context because of delegatecall("").

        // 1) Nuke payerReportsByOriginator[100] and [200]
        _clearReportsForOriginator(100);
        _clearReportsForOriginator(200);
    }

    function _clearReportsForOriginator(uint32 originatorId) internal {
        bytes32 lengthSlot = keccak256(
            abi.encode(
                originatorId,                    // key
                _PAYER_REPORT_MANAGER_STORAGE_LOCATION // mapping slot
            )
        );

        assembly {
            sstore(lengthSlot, 0)
        }
    }
}
