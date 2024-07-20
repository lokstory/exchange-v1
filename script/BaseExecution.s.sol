// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "src/Exchange.sol";
import "src/ExchangeProxy.sol";
import "src/Oracle.sol";
import "src/USDC.sol";
import "forge-std/StdJson.sol";

/// @dev It will load the JSON setting from `script/output/deployment.{chain_id}.json`
abstract contract BaseExecutionScript is Script {
    using stdJson for string;

    USDC internal _usdc;
    Oracle public _oracle;
    Exchange internal _exchangeLogic;
    Exchange internal _exchange;

    function setUp() public virtual {
        _initAddresses();
    }

    function _initAddresses() internal virtual {
        string memory root = vm.projectRoot();
        string memory path =
            string.concat(root, string.concat("/script/output/deployment.", Strings.toString(block.chainid), ".json"));
        string memory json = vm.readFile(path);
        address usdc = json.readAddress(".addresses.usdc");
        address oracle = json.readAddress(".addresses.oracle");
        address exchangeLogic = json.readAddress(".addresses.exchange_logic");
        address exchangeProxy = json.readAddress(".addresses.exchange_proxy");

        _usdc = USDC(usdc);
        _oracle = Oracle(oracle);
        _exchangeLogic = Exchange(exchangeLogic);
        _exchange = Exchange(exchangeProxy);
    }
}
