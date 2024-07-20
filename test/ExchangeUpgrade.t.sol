// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "test/Exchange.t.sol";

contract ExchangeHarnessV2 is ExchangeHarness {
    constructor(address tokenIn_, address tokenOut_) ExchangeHarness(tokenIn_, tokenOut_) {}

    function hello() external pure returns (string memory) {
        return "world";
    }
}

/// @notice Tests the functions work as expected after upgrading the logic contract
contract ExchangeUpgradeTest is ExchangeTest {
    function setUp() public override {
        super.setUp();

        // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        ExchangeHarnessV2 logicV2 = new ExchangeHarnessV2(TokenUtils.NATIVE_TOKEN, address(_usdc));

        vm.expectEmit(true, true, true, true, address(_exchangeProxy));
        emit ERC1967Utils.Upgraded(address(logicV2));

        _proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_exchangeProxy)), address(logicV2), "");

        assertEq(
            address(uint160(uint256(vm.load(address(_exchangeProxy), implementationSlot)))),
            address(logicV2),
            "implementation"
        );

        _exchangeLogic = ExchangeHarness(address(logicV2));
    }

    function test_hello() public view {
        assertEq(ExchangeHarnessV2(address(_exchange)).hello(), "world");
    }
}
