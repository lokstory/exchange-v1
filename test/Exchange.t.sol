// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "test/BaseV1.t.sol";

/// @dev Tests are not enough for a product,
///      just to demonstrate it could be very complete.
contract ExchangeTest is BaseV1Test {
    using Math for uint256;
    using SafeCast for *;
    using SafeERC20 for IERC20;

    struct SwapVars {
        address account;
        uint256 amountIn;
        uint256 minAmountOut;
        uint48 deadline;
        uint256 price;
        uint256 amountOut;
        uint256 feeOut;
    }

    uint256 public constant DEFAULT_PRICE = 3000e6;

    address internal immutable _user = makeAddr("user");

    function test_deposit_FailWhenNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _user));
        vm.startPrank(_user);
        _exchange.deposit(address(_usdc), 1e6);
        vm.stopPrank();
    }

    function test_deposit() public {
        _assertDeposited(address(_usdc), 100e6);
    }

    function test_deposit_FailWhenNativeTokenIncorrectPay() public {
        address token = address(_usdc);
        address owner = address(this);
        uint256 amount = 1e6;
        deal(token, owner, amount);

        vm.expectRevert(abi.encodeWithSelector(TokenUtils.NativeTokenIncorrectPay.selector));
        vm.startPrank(owner);
        _exchange.deposit{value: 1}(token, amount);
        vm.stopPrank();
    }

    function test_withdraw_FailWhenNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _user));
        vm.startPrank(_user);
        _exchange.withdraw(address(_usdc), 1e6);
        vm.stopPrank();
    }

    function test_withdraw_WhenWithdrawUSDC() public {
        _assertDeposited(address(_usdc), 100e6);
        _assertWithdrawn(address(_usdc), 50e6);
        _assertWithdrawn(address(_usdc), 50e6);
    }

    function test_swap_FailWhenPaused() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 1e18;
        vars.price = DEFAULT_PRICE;
        vars.deadline = 1;

        deal(vars.account, vars.amountIn);

        _calculateAmountAndFeeOut(vars);
        _assertDeposited(_exchange.tokenOut(), vars.amountOut);

        _exchange.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.startPrank(vars.account);
        _exchange.swap{value: vars.amountIn}(vars.amountIn, vars.minAmountOut, vars.deadline);
        vm.stopPrank();
    }

    function test_swap_FailWhenDeadlineExceeded() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 1e18;
        vars.price = DEFAULT_PRICE;
        vars.deadline = 1;

        deal(vars.account, vars.amountIn);

        _calculateAmountAndFeeOut(vars);
        _assertDeposited(_exchange.tokenOut(), vars.amountOut);

        vm.warp(2);

        vm.expectRevert(abi.encodeWithSelector(IExchange.DeadlineExceeded.selector));
        vm.startPrank(vars.account);
        _exchange.swap{value: vars.amountIn}(vars.amountIn, vars.minAmountOut, vars.deadline);
        vm.stopPrank();
    }

    function test_swap_FailWhenAmountOutLessThanMin() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 1e18;
        vars.price = DEFAULT_PRICE;

        deal(vars.account, vars.amountIn);

        _calculateAmountAndFeeOut(vars);
        _assertDeposited(_exchange.tokenOut(), vars.amountOut);

        vars.minAmountOut = vars.amountOut + 1;

        vm.expectRevert(abi.encodeWithSelector(IExchange.SwapResultInvalid.selector));
        vm.startPrank(vars.account);
        _exchange.swap{value: vars.amountIn}(vars.amountIn, vars.minAmountOut, vars.deadline);
        vm.stopPrank();
    }

    function test_swap_FailWhenAmountOutZeroByPrice() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 100e12;
        vars.price = 0.001e6;

        deal(vars.account, vars.amountIn);

        _calculateAmountAndFeeOut(vars);
        _mockGetLatestRound(vars.price);

        vm.expectRevert(abi.encodeWithSelector(IExchange.SwapResultInvalid.selector));
        vm.startPrank(vars.account);
        _exchange.swap{value: vars.amountIn}(vars.amountIn, vars.minAmountOut, vars.deadline);
        vm.stopPrank();
    }

    function test_swap_FailWhenAmountOutZeroByFee() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 1e12;
        vars.price = 1e6;

        deal(vars.account, vars.amountIn);

        _exchange.setFeeRatio(1);
        _calculateAmountAndFeeOut(vars);

        _mockGetLatestRound(vars.price);

        vm.expectRevert(abi.encodeWithSelector(IExchange.SwapResultInvalid.selector));
        vm.startPrank(vars.account);
        _exchange.swap{value: vars.amountIn}(vars.amountIn, vars.minAmountOut, vars.deadline);
        vm.stopPrank();
    }

    function test_swap() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 1e18;
        vars.price = DEFAULT_PRICE;

        (uint256 amountOut, uint256 feeOut) = _assertSwappedWithCalculation(vars);
        assertEq(amountOut, 3000e6, "amount out");
        assertEq(feeOut, 0, "fee out");
    }

    function test_swap_WhenUnpause() public {
        SwapVars memory vars;
        vars.account = _user;
        vars.amountIn = 1e18;
        vars.price = DEFAULT_PRICE;

        _exchange.pause();
        _exchange.unpause();

        _assertSwappedWithCalculation(vars);
    }

    function testFuzz_swap(SwapVars memory vars, uint48 blockTime, uint96 feeRatio) public {
        vm.assume(
            vars.account > address(0) && vars.account != address(_exchange) && vars.account != address(_proxyAdmin)
        );

        blockTime = bound(blockTime, 0, type(uint40).max).toUint48();
        vars.price = bound(vars.price, 0.1e6, 1000000e6);
        vars.amountIn = bound(vars.amountIn, 1e18, type(uint96).max);

        // 0 - 50%
        feeRatio = bound(feeRatio, 0, 0.5e18).toUint96();
        _exchange.setFeeRatio(feeRatio);

        _calculateAmountAndFeeOut(vars);

        vars.deadline = bound(vars.deadline, blockTime, type(uint48).max).toUint48();
        vars.minAmountOut = bound(vars.minAmountOut, 0, vars.amountOut);

        vm.warp(blockTime);

        _assertSwapped(vars);
    }

    function test_calculateSwapResult_FailWhenPriceZero() public {
        vm.mockCall(address(_oracle), abi.encodeWithSelector(IOracle.getLatestRound.selector), abi.encode(1, 0, 1));
        vm.expectRevert(abi.encodeWithSelector(IExchange.PriceInvalid.selector));
        _exchange.exposed_calculateSwapResult(1);
    }

    function test_calculateSwapResult_FailWhenPriceStaled() public {
        vm.warp(_exchange.getPriceStalenessSeconds() + 2);

        vm.mockCall(address(_oracle), abi.encodeWithSelector(IOracle.getLatestRound.selector), abi.encode(1, 1000e6, 1));
        vm.expectRevert(abi.encodeWithSelector(IExchange.PriceStaled.selector));
        _exchange.exposed_calculateSwapResult(1);
    }

    function test_checkAmountPositive_FailWhenAmountZero() public {
        vm.expectRevert(abi.encodeWithSelector(IExchange.ParameterInvalid.selector));
        _exchange.exposed_checkAmountPositive(0);
    }

    function _assertDeposited(address token, uint256 amount) internal {
        address owner = address(this);
        _usdc.mint(address(owner), amount);

        uint256 ownerBalanceBefore = TokenUtils.getBalance(token, owner);
        uint256 balanceBefore = TokenUtils.getBalance(token, address(_exchange));
        uint256 poolBalanceBefore = _exchange.getPoolBalance(token);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IPoolBalances.PoolBalanceUpdated(token, poolBalanceBefore + amount);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IExchange.Deposited(owner, token, amount);

        vm.startPrank(owner);
        _exchange.deposit(token, amount);
        vm.stopPrank();

        assertEq(TokenUtils.getBalance(token, owner), ownerBalanceBefore - amount, "owner balance");
        assertEq(TokenUtils.getBalance(token, address(_exchange)), balanceBefore + amount, "balance");
        assertEq(_exchange.getPoolBalance(token), poolBalanceBefore + amount, "pool balance");
    }

    function _assertWithdrawn(address token, uint256 amount) internal {
        address owner = address(this);

        uint256 ownerBalanceBefore = TokenUtils.getBalance(token, owner);
        uint256 balanceBefore = TokenUtils.getBalance(token, address(_exchange));
        uint256 poolBalanceBefore = _exchange.getPoolBalance(token);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IPoolBalances.PoolBalanceUpdated(token, poolBalanceBefore - amount);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IExchange.Withdrawn(owner, token, amount);

        vm.startPrank(owner);
        _exchange.withdraw(token, amount);
        vm.stopPrank();

        assertEq(TokenUtils.getBalance(token, owner), ownerBalanceBefore + amount, "owner balance");
        assertEq(TokenUtils.getBalance(token, address(_exchange)), balanceBefore - amount, "balance");
        assertEq(_exchange.getPoolBalance(token), poolBalanceBefore - amount, "pool balance");
    }

    function _assertSwappedWithCalculation(SwapVars memory vars) internal returns (uint256 amountOut, uint256 feeOut) {
        _calculateAmountAndFeeOut(vars);

        return _assertSwapped(vars);
    }

    function _assertSwapped(SwapVars memory vars) internal returns (uint256 amountOut, uint256 feeOut) {
        address tokenIn = _exchange.tokenIn();
        address tokenOut = _exchange.tokenOut();
        uint256 msgValue;

        if (TokenUtils.isNativeToken(tokenIn)) {
            deal(vars.account, vars.amountIn);
            msgValue = vars.amountIn;
        } else {
            deal(tokenIn, vars.account, vars.amountIn);

            if (IERC20(tokenIn).allowance(vars.account, address(_exchange)) < vars.amountIn) {
                vm.startPrank(vars.account);
                IERC20(tokenIn).forceApprove(address(_exchange), vars.amountIn);
                vm.stopPrank();
            }
        }

        if (!TokenUtils.isNativeToken(tokenOut) && _exchange.getPoolBalance(tokenOut) < vars.amountOut) {
            _assertDeposited(tokenOut, vars.amountOut);
        }

        uint256 accountBalanceInBefore = TokenUtils.getBalance(tokenIn, vars.account);
        uint256 accountBalanceOutBefore = TokenUtils.getBalance(tokenOut, vars.account);
        uint256 poolBalanceInBefore = _exchange.getPoolBalance(tokenIn);
        uint256 poolBalanceOutBefore = _exchange.getPoolBalance(tokenOut);

        _mockGetLatestRound(vars.price);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IPoolBalances.PoolBalanceUpdated(tokenIn, poolBalanceInBefore + vars.amountIn);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IPoolBalances.PoolBalanceUpdated(tokenOut, poolBalanceOutBefore - vars.amountOut);

        vm.expectEmit(true, true, true, true, address(_exchange));
        emit IExchange.Swapped(vars.account, vars.amountIn, vars.amountOut, vars.feeOut);

        vm.startPrank(vars.account);
        (amountOut, feeOut) = _exchange.swap{value: msgValue}(vars.amountIn, vars.minAmountOut, vars.deadline);
        vm.stopPrank();

        assertEq(
            TokenUtils.getBalance(tokenIn, vars.account), accountBalanceInBefore - vars.amountIn, "account balance in"
        );
        assertEq(
            TokenUtils.getBalance(tokenOut, vars.account),
            accountBalanceOutBefore + vars.amountOut,
            "account balance out"
        );
        assertEq(_exchange.getPoolBalance(tokenIn), poolBalanceInBefore + vars.amountIn, "pool balance in");
        assertEq(_exchange.getPoolBalance(tokenOut), poolBalanceOutBefore - vars.amountOut, "pool balance out");
        assertEq(amountOut, vars.amountOut, "amount out");
        assertEq(feeOut, vars.feeOut, "fee out");
    }

    function _mockGetLatestRound(uint256 price) internal {
        vm.mockCall(
            address(_oracle),
            abi.encodeWithSelector(IOracle.getLatestRound.selector),
            abi.encode(1, price, block.timestamp.toUint48())
        );
    }

    function _calculateAmountAndFeeOut(SwapVars memory vars) internal view {
        vars.amountOut = vars.amountIn.mulDiv(vars.price, 1e18);

        uint256 feeRatio = _exchange.getFeeRatio();
        if (feeRatio > 0) {
            vars.feeOut = vars.amountOut.mulDiv(feeRatio, 1e18, Math.Rounding.Ceil);
            vars.amountOut -= vars.feeOut;
        } else {
            vars.feeOut = 0;
        }
    }
}
