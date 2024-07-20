// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TokenUtils {
    using SafeERC20 for IERC20;

    address internal constant NATIVE_TOKEN = address(0);

    /// @notice Thrown if transfer of ERC20 tokens fails
    error ERC20TransferFailed();
    /// @notice Thrown if transfer of native tokens fails
    error NativeTokenTransferFailed();
    /// @notice Thrown if the amount of the native token is incorrect,
    ///         or if native tokens are sent when ERC20 tokens are expected.
    error NativeTokenIncorrectPay();

    /// @notice Transfers the `amount` of `token` to the `receiver`
    function transferToken(address token, address receiver, uint256 amount) internal {
        if (isNativeToken(token)) {
            transferNativeToken(receiver, amount);
        } else {
            transferERC20(IERC20(token), receiver, amount);
        }
    }

    /// @notice Transfers the `amount` of native tokens to the `receiver`
    function transferNativeToken(address receiver, uint256 amount) internal {
        bool success;

        assembly {
            success := call(gas(), receiver, amount, 0, 0, 0, 0)
        }

        if (!success) revert NativeTokenTransferFailed();
    }

    /// @notice Transfers the `amount` of ERC20 `token` to the `receiver`
    function transferERC20(IERC20 token, address receiver, uint256 amount) internal {
        token.safeTransfer(receiver, amount);
    }

    /// @notice Transfers `amount` of ERC20 `token` from `sender` to `receiver`
    function transferERC20From(IERC20 token, address sender, address receiver, uint256 amount) internal {
        token.safeTransferFrom(sender, receiver, amount);
    }

    /// @notice Gets the balance of the specified `account` for the given `token`
    function getBalance(address token, address account) internal view returns (uint256) {
        if (isNativeToken(token)) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    /// @notice Gets the decimal places for the specified `token`
    function getDecimals(address token) internal view returns (uint8) {
        if (isNativeToken(token)) {
            return 18;
        } else {
            return IERC20Metadata(token).decimals();
        }
    }

    /// @return Returns true if the `token` is the native token
    function isNativeToken(address token) internal pure returns (bool) {
        return token == NATIVE_TOKEN;
    }
}
