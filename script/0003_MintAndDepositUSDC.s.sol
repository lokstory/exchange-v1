// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "script/BaseExecution.s.sol";

/// @notice Deposits USDC tokens to the exchange pool
/// @custom:cmd USDC_DEPOSIT_AMOUNT=$USDC_DEPOSIT_AMOUNT forge script script/0003_MintAndDepositUSDC.s.sol --fork-url sepolia --broadcast --slow --private-key $PRIVATE_KEY
/// @custom:env USDC_DEPOSIT_AMOUNT The initial USDC pool balance
contract MintAndDepositUSDCScript is BaseExecutionScript {
    using SafeERC20 for IERC20;

    function run() public {
        uint256 amount = vm.envUint("USDC_DEPOSIT_AMOUNT");

        if (IERC20(address(_usdc)).allowance(msg.sender, address(_exchange)) < amount) {
            vm.startBroadcast();
            IERC20(address(_usdc)).forceApprove(address(_exchange), amount);
            vm.stopBroadcast();
        }

        vm.startBroadcast();

        _usdc.mint(msg.sender, amount);
        _exchange.deposit(address(_usdc), amount);

        vm.stopBroadcast();
    }
}
