// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import "src/Exchange.sol";
import "src/ExchangeProxy.sol";
import "src/USDC.sol";
import "test/harnesses/ExchangeHarness.sol";
import "test/mocks/MockOracle.sol";

abstract contract BaseV1Test is Test {
    USDC internal _usdc;
    MockOracle internal _oracle;
    ExchangeProxy internal _exchangeProxy;
    ExchangeHarness internal _exchangeLogic;
    ExchangeHarness internal _exchange;
    ProxyAdmin internal _proxyAdmin;

    function setUp() public virtual {
        _usdc = new USDC();
        _oracle = new MockOracle();
        _exchangeLogic = new ExchangeHarness(TokenUtils.NATIVE_TOKEN, address(_usdc));
        IExchange.InitializeConfig memory config =
            IExchange.InitializeConfig({oracle: IOracle(address(_oracle)), feeRatio: 0, priceStalenessSeconds: 1 days});
        _exchangeProxy = new ExchangeProxy(address(_exchangeLogic), address(this), config);
        _exchange = ExchangeHarness(address(_exchangeProxy));

        // openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol
        // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        bytes32 proxyAdminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        _proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(_exchangeProxy), proxyAdminSlot)))));

        _usdc.approve(address(_exchange), type(uint256).max);
    }
}
