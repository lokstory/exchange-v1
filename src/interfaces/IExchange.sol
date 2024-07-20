// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "src/interfaces/IOracle.sol";

interface IExchange {
    struct InitializeConfig {
        IOracle oracle;
        uint96 feeRatio;
        uint48 priceStalenessSeconds;
    }

    /// @notice Emitted when the oracle is updated to the `newOracle`
    event OracleUpdated(IOracle newOracle);

    /// @notice Emitted when the fee ratio is updated to the `newFee`
    event FeeUpdated(uint96 newFee);

    /// @notice Emitted when the price staleness seconds is updated to the `newSeconds`
    event PriceStalenessSecondsUpdated(uint48 newSeconds);

    /// @notice Emitted when `account` performs a token exchange
    /// @param account The address of the account that performed the swap
    /// @param amountIn The amount of tokens swapped in
    /// @param amountOut The amount of tokens received
    /// @param feeOut The fee deducted from the amount received
    event Swapped(address indexed account, uint256 amountIn, uint256 amountOut, uint256 feeOut);

    /// @notice Emitted when the owner deposits tokens into the pool
    /// @param account The address of the owner
    /// @param token The address of the token deposited
    /// @param amount The amount of tokens deposited
    event Deposited(address indexed account, address indexed token, uint256 amount);

    /// @notice Emitted when the owner withdraws tokens from the pool
    /// @param account The address of the owner
    /// @param token The address of the token withdrawn
    /// @param amount The amount of tokens withdrawn
    event Withdrawn(address indexed account, address indexed token, uint256 amount);

    error DeadlineExceeded();
    error PairInvalid();
    error ParameterInvalid();
    error PriceInvalid();
    error PriceStaled();
    error SwapResultInvalid();
    error TokenInvalid(address token);

    /// @notice Initializes the contract with the provided configuration
    function initialize(InitializeConfig memory config_) external;

    /// @notice Pauses the swap feature
    function pause() external;

    /// @notice Unpauses the swap feature
    function unpause() external;

    /// @notice Updates the fee ratio to the specified `newFee`
    function setFeeRatio(uint96 newFee) external;

    /// @notice Updates the price staleness threshold to the specified `newSeconds`
    function setPriceStalenessSeconds(uint48 newSeconds) external;

    /// @notice Swaps `amountIn` of `tokenIn` for `tokenOut`
    /// @param amountIn The amount of `tokenIn` to swap
    /// @param minAmountOut The minimum amount of `tokenOut` expected from the swap
    /// @param deadline The latest time by which the swap must be completed
    /// @return amountOut The amount of `tokenOut` received from the swap
    /// @return feeOut The fee deducted during the swap
    function swap(uint256 amountIn, uint256 minAmountOut, uint48 deadline)
        external
        payable
        returns (uint256 amountOut, uint256 feeOut);

    /// @notice Deposits the specified `amount` of the `token` into the pool, accessible only by the owner.
    function deposit(address token, uint256 amount) external payable;

    /// @notice Withdraws the specified amount of the token from the pool, callable only by the owner
    function withdraw(address token, uint256 amount) external payable;

    /// @return The fee ratio, expressed with 18 decimal places, as a uint96 value
    function tokenIn() external view returns (address);

    /// @return The address of the oracle
    function getOracle() external view returns (IOracle);

    /// @notice Retrieves the current fee ratio
    /// @return The fee ratio, expressed with 18 decimal places, as a uint96 value
    function getFeeRatio() external view returns (uint96);

    /// @notice Retrieves the current setting for the price staleness threshold
    /// @return The maximum allowable time in seconds before a price is considered stale
    function getPriceStalenessSeconds() external view returns (uint48);
}
