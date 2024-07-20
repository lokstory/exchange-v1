// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPoolBalances {
    /// @notice Emitted when the pool balance of the specified `token` has been updated to `newBalance`
    event PoolBalanceUpdated(address indexed token, uint256 newBalance);

    /// @notice Thrown if the pool balance of the specified `token` is insufficient
    error PoolBalanceInsufficient(address token);

    /// @notice Gets the pool balance of the specified `token`
    function getPoolBalance(address token) external view returns (uint256);
}
