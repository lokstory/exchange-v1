// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "src/Exchange.sol";
import "src/ExchangeProxy.sol";
import "src/Oracle.sol";
import "src/USDC.sol";

/// @notice Deploys the contracts to the testnet
///         <a href="https://faucets.chain.link/sepolia">Gets the LINK and ETH tokens on Sepolia first</a>
/// @dev When deployed the contracts, it will save the JSON file to `script/output/deployment.{chain_id}.json`.
/// @custom:cmd forge script script/0001_DeployContracts.s.sol --fork-url sepolia --broadcast --slow --verify --private-key $PRIVATE_KEY
/// @custom:env CHAINLINK_TOKEN The address of the LINK token
/// @custom:env CHAINLINK_OPERATOR The address of the Chainlink operator
/// @custom:env CHAINLINK_JOB_ID <a href="https://docs.chain.link/any-api/testnet-oracles/#operator-contracts">JOB ID</a>
/// @custom:env EXCHANGE_FEE_RATIO The fee ratio, expressed with 18 decimal places, which can be zero or less than 1e18 (100%)
/// @custom:env EXCHANGE_PRICE_STALENESS_SECONDS The price staleness threshold in seconds
contract DeployContractsScript is Script {
    using SafeCast for *;

    USDC internal _usdc;
    Oracle public _oracle;
    Exchange internal _exchangeLogic;
    ExchangeProxy internal _exchangeProxy;

    function run() public {
        _deployUSDC();
        _deployOracle();
        _deployExchangeLogic();
        _deployExchangeProxy();

        _outputResult();
    }

    function _deployUSDC() internal {
        vm.startBroadcast();

        _usdc = new USDC();

        vm.stopBroadcast();
    }

    function _deployOracle() internal {
        address linkToken = vm.envAddress("CHAINLINK_TOKEN");
        address chainlinkOperator = vm.envAddress("CHAINLINK_OPERATOR");
        string memory jobId = vm.envString("CHAINLINK_JOB_ID");
        uint256 oracleInitialBalance = vm.envUint("ORACLE_INITIAL_BALANCE");

        vm.startBroadcast();

        _oracle = new Oracle(linkToken, chainlinkOperator, bytes32(bytes(jobId)));

        if (oracleInitialBalance > 0) {
            IERC20(linkToken).transfer(address(_oracle), oracleInitialBalance);
        }

        vm.stopBroadcast();
    }

    function _deployExchangeLogic() internal {
        vm.startBroadcast();

        _exchangeLogic = new Exchange(TokenUtils.NATIVE_TOKEN, address(_usdc));

        vm.stopBroadcast();
    }

    function _deployExchangeProxy() internal {
        uint256 feeRatio = vm.envUint("EXCHANGE_FEE_RATIO");
        uint256 priceStalenessSeconds = vm.envUint("EXCHANGE_PRICE_STALENESS_SECONDS");

        IExchange.InitializeConfig memory config = IExchange.InitializeConfig({
            oracle: IOracle(address(_oracle)),
            feeRatio: feeRatio.toUint96(),
            priceStalenessSeconds: priceStalenessSeconds.toUint48()
        });

        vm.startBroadcast();

        _exchangeProxy = new ExchangeProxy(address(_exchangeLogic), msg.sender, config);

        vm.stopBroadcast();
    }

    function _outputResult() internal {
        console.log("usdc", address(_usdc));
        console.log("oracle", address(_oracle));
        console.log("exchange logic", address(_exchangeLogic));
        console.log("exchange proxy", address(_exchangeProxy));

        string memory root = "root";

        string memory addresses = "addresses";
        vm.serializeAddress(addresses, "oracle", address(_oracle));
        vm.serializeAddress(addresses, "usdc", address(_usdc));
        vm.serializeAddress(addresses, "exchange_logic", address(_exchangeLogic));
        string memory addressOutput = vm.serializeAddress(addresses, "exchange_proxy", address(_exchangeProxy));

        string memory info = "info";
        vm.serializeUint(info, "block_number", block.number);
        vm.serializeUint(info, "block_timestamp", block.timestamp);
        string memory infoOutput = vm.serializeUint(info, "chainId", block.chainid);

        // serialize all the data
        vm.serializeString(root, addresses, addressOutput);
        string memory finalJson = vm.serializeString(root, info, infoOutput);
        vm.writeJson(finalJson, string.concat("script/output/deployment.", Strings.toString(block.chainid), ".json"));
    }
}
