// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library AddressUtils {
    /// @notice Thrown if `addr` is zero
    error AddressZero(address addr);

    /// @notice Thrown if the code size of the `addr` is zero
    error AddressCodeSizeZero(address addr);

    /// @notice Reverts if the `addr` is zero or the code size of it is zero
    function checkContract(address addr) internal view {
        checkNotZero(addr);

        uint256 size;

        assembly {
            size := extcodesize(addr)
        }

        if (size == 0) revert AddressCodeSizeZero(addr);
    }

    /// @notice Reverts if the `addr` is zero
    function checkNotZero(address addr) internal pure {
        if (addr == address(0)) revert AddressZero(addr);
    }
}
