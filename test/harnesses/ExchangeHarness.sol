// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/Exchange.sol";

contract ExchangeHarness is Exchange {
    constructor(address tokenIn_, address tokenOut_) Exchange(tokenIn_, tokenOut_) {}

    function exposed_calculateSwapResult(uint256 amountIn) external view returns (uint256 amountOut, uint256 feeOut) {
        return _calculateSwapResult(amountIn);
    }

    function exposed_checkAmountPositive(uint256 amount) external pure {
        if (amount == 0) revert ParameterInvalid();
    }
}
