// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "src/interfaces/IExchange.sol";
import "src/utils/AddressUtils.sol";
import "src/utils/Constants.sol";
import "src/utils/TokenUtils.sol";
import "src/PoolBalancesUpgradeable.sol";

/// @title Exchange
/// @notice This contract facilitates swapping from `tokenIn` to `tokenOut`
contract Exchange is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    PoolBalancesUpgradeable,
    IExchange
{
    using Math for uint256;
    using SafeCast for *;
    using SafeERC20 for IERC20;

    address public immutable tokenIn;
    address public immutable tokenOut;

    IOracle internal _oracle;
    uint96 internal _feeRatio;
    uint48 internal _priceStalenessSeconds;

    /// @notice Reverts if the `token` is not a pool token
    modifier onlyPoolToken(address token) {
        if (token != tokenIn && token != tokenOut) revert TokenInvalid(token);

        _;
    }

    /// @notice Checks that the balance of `account` has increased by at least `amount`
    ///         after the function has executed
    modifier ensureERC20BalanceIncreasedAfter(IERC20 token, address account, uint256 amount) {
        uint256 balanceBefore = token.balanceOf(account);

        _;

        if (token.balanceOf(account) < balanceBefore + amount) revert TokenUtils.ERC20TransferFailed();
    }

    /// @notice Checks that the current time does not exceed the specified `deadline` if the deadline is set
    modifier ensureDeadlineNotExceeded(uint48 deadline) {
        if (deadline > 0 && block.timestamp > deadline) revert DeadlineExceeded();

        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address tokenIn_, address tokenOut_) {
        _disableInitializers();

        if (tokenIn_ == tokenOut_) revert PairInvalid();
        if (!TokenUtils.isNativeToken(tokenIn_)) {
            AddressUtils.checkContract(tokenIn_);
        }
        if (!TokenUtils.isNativeToken(tokenOut_)) {
            AddressUtils.checkContract(tokenOut_);
        }

        tokenIn = tokenIn_;
        tokenOut = tokenOut_;
    }

    /// @inheritdoc IExchange
    function initialize(InitializeConfig memory config_) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        _setOracle(config_.oracle);
        _setFeeRatio(config_.feeRatio);
        _setPriceStalenessSeconds(config_.priceStalenessSeconds);
    }

    /// @inheritdoc IExchange
    function pause() external onlyOwner {
        _pause();
    }

    /// @inheritdoc IExchange
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc IExchange
    function setFeeRatio(uint96 newFee) external onlyOwner {
        _setFeeRatio(newFee);
    }

    /// @inheritdoc IExchange
    function setPriceStalenessSeconds(uint48 newSeconds) external onlyOwner {
        _setPriceStalenessSeconds(newSeconds);
    }

    /// @inheritdoc IExchange
    function swap(uint256 amountIn, uint256 minAmountOut, uint48 deadline)
        external
        payable
        whenNotPaused
        nonReentrant
        ensureDeadlineNotExceeded(deadline)
        returns (uint256 amountOut, uint256 feeOut)
    {
        _checkDepositAmount(tokenIn, amountIn);

        (amountOut, feeOut) = _calculateSwapResult(amountIn);
        if (amountOut == 0 || amountOut < minAmountOut) revert SwapResultInvalid();

        _deposit(tokenIn, amountIn);
        _withdraw(tokenOut, amountOut);

        emit Swapped(msg.sender, amountIn, amountOut, feeOut);
    }

    /// @inheritdoc IExchange
    function deposit(address token, uint256 amount) external payable onlyOwner nonReentrant {
        if (token != tokenOut) revert TokenInvalid(token);
        _checkDepositAmount(token, amount);

        _deposit(token, amount);

        emit Deposited(msg.sender, token, amount);
    }

    /// @inheritdoc IExchange
    function withdraw(address token, uint256 amount) external payable onlyOwner onlyPoolToken(token) nonReentrant {
        _checkAmountPositive(amount);

        _withdraw(token, amount);

        emit Withdrawn(msg.sender, token, amount);
    }

    /// @inheritdoc IExchange
    function getOracle() public view returns (IOracle) {
        return _oracle;
    }

    /// @inheritdoc IExchange
    function getFeeRatio() public view returns (uint96) {
        return _feeRatio;
    }

    /// @inheritdoc IExchange
    function getPriceStalenessSeconds() public view returns (uint48) {
        return _priceStalenessSeconds;
    }

    function _setOracle(IOracle newOracle) internal {
        AddressUtils.checkContract(address(newOracle));

        _oracle = newOracle;

        emit OracleUpdated(newOracle);
    }

    function _setFeeRatio(uint96 newRatio) internal {
        if (newRatio >= Constants.BASE) revert ParameterInvalid();

        _feeRatio = newRatio;

        emit FeeUpdated(newRatio);
    }

    function _setPriceStalenessSeconds(uint48 newSeconds) internal {
        if (newSeconds == 0) revert ParameterInvalid();

        _priceStalenessSeconds = newSeconds;

        emit PriceStalenessSecondsUpdated(newSeconds);
    }

    /// @notice Transfers a specified amount of ERC20 tokens to the pool
    /// @dev The function will check that the pool's balance has increased by at least the specified amount after the transfer.
    ///      Currently, fee-on-transfer tokens are not supported.
    /// @param token The address of the ERC20 token contract
    /// @param sender The address of the token payer
    /// @param amount The amount of tokens to transfer
    function _pullERC20(IERC20 token, address sender, uint256 amount)
        internal
        ensureERC20BalanceIncreasedAfter(token, address(this), amount)
    {
        TokenUtils.transferERC20From(token, sender, address(this), amount);
    }

    function _deposit(address token, uint256 amount) internal {
        if (!TokenUtils.isNativeToken(token)) {
            _pullERC20(IERC20(token), msg.sender, amount);
        }

        _increasePoolBalance(token, amount);
    }

    function _withdraw(address token, uint256 amount) internal {
        _decreasePoolBalance(token, amount);

        TokenUtils.transferToken(token, msg.sender, amount);
    }

    function _calculateSwapResult(uint256 amountIn) internal view returns (uint256 amountOut, uint256 feeOut) {
        (, uint256 price, uint48 timestamp) = _oracle.getLatestRound();

        if (price == 0) revert PriceInvalid();
        if (block.timestamp >= timestamp && block.timestamp - timestamp > _priceStalenessSeconds) revert PriceStaled();

        uint8 priceDecimals = _oracle.decimals();
        amountOut = amountIn.mulDiv(
            price * (10 ** TokenUtils.getDecimals(tokenOut)),
            (10 ** priceDecimals) * (10 ** TokenUtils.getDecimals(tokenIn))
        );

        uint256 feeRatio = _feeRatio;
        if (feeRatio > 0) {
            feeOut = amountOut.mulDiv(feeRatio, Constants.BASE, Math.Rounding.Ceil);
            amountOut -= feeOut;
        }
    }

    function _checkDepositAmount(address token, uint256 amount) internal view {
        _checkAmountPositive(amount);

        if (TokenUtils.isNativeToken(token)) {
            if (amount != msg.value) revert TokenUtils.NativeTokenIncorrectPay();
        } else {
            if (msg.value > 0) revert TokenUtils.NativeTokenIncorrectPay();
        }
    }

    function _checkAmountPositive(uint256 amount) internal pure {
        if (amount == 0) revert ParameterInvalid();
    }
}
