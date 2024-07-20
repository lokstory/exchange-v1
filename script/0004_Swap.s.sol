// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "script/BaseExecution.s.sol";

/// @notice Deposits USDC tokens to the exchange pool
/// @custom:cmd AMOUNT_IN=$AMOUNT_IN forge script script/0004_Swap.s.sol --fork-url sepolia --broadcast --slow --private-key $PRIVATE_KEY
/// @custom:env AMOUNT_IN The amount of wei to spend
contract SwapScript is BaseExecutionScript {
    function run() public {
        uint256 amountIn = vm.envUint("AMOUNT_IN");

        vm.startBroadcast();

        _exchange.swap{value: amountIn}(amountIn, 0, 0);

        vm.stopBroadcast();
    }
}
