// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/interfaces/IPoolBalances.sol";

/// @title PoolBalanceUpgradeable
/// @notice Manages and accounts for pool assets with support for upgradeable functionality.
/// @custom:storage-size 50
abstract contract PoolBalancesUpgradeable is IPoolBalances {
    mapping(address token => uint256) internal _poolBalance;

    /// @inheritdoc IPoolBalances
    function getPoolBalance(address token) public view returns (uint256) {
        return _poolBalance[token];
    }

    /// @notice Increases the pool balance by the specified `amount` of the `token`
    function _increasePoolBalance(address token, uint256 amount) internal {
        _updatePoolBalance(token, _poolBalance[token] + amount);
    }

    /// @notice Decreases the pool balance by the specified `amount` of the `token`
    function _decreasePoolBalance(address token, uint256 amount) internal {
        if (_poolBalance[token] < amount) revert PoolBalanceInsufficient(token);
        _updatePoolBalance(token, _poolBalance[token] - amount);
    }

    /// @notice Updates the pool balance of the specified `token` to `newBalance`
    function _updatePoolBalance(address token, uint256 newBalance) internal {
        _poolBalance[token] = newBalance;
        emit PoolBalanceUpdated(token, newBalance);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
