// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "src/interfaces/IExchange.sol";

contract ExchangeProxy is TransparentUpgradeableProxy {
    constructor(address logic_, address proxyAdminOwner_, IExchange.InitializeConfig memory config_)
        TransparentUpgradeableProxy(
            logic_,
            proxyAdminOwner_,
            abi.encodeWithSelector(IExchange.initialize.selector, config_)
        )
    {}
}
