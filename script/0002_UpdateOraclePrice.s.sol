// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "script/BaseExecution.s.sol";

/// @notice Requests to update the oracle price
/// @custom:cmd forge script script/0002_UpdateOraclePrice.s.sol --fork-url sepolia --broadcast --slow --private-key $PRIVATE_KEY
contract UpdateOraclePriceScript is BaseExecutionScript {
    function run() public {
        vm.startBroadcast();

        _oracle.requestNewPrice();

        vm.stopBroadcast();
    }
}
