// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "src/interfaces/IOracle.sol";

contract MockOracle is IOracle {
    using SafeCast for *;

    function requestNewPrice() external pure returns (bytes32 requestId) {
        return bytes32(0);
    }

    function fulfill(bytes32, uint256) external {}

    function withdrawLink() external {}

    function latestPrice() external pure returns (uint256) {
        return 0;
    }

    function latestTimestamp() external pure returns (uint48) {
        return 0;
    }

    function latestRoundId() external pure returns (uint256) {
        return 1;
    }

    function getPrice(uint256) external pure returns (uint256) {
        return 0;
    }

    function getTimestamp(uint256) external pure returns (uint48) {
        return 0;
    }

    function getLatestRound() external view returns (uint256 roundId, uint256 price, uint48 timestamp) {
        return (1, 3000e6, block.timestamp.toUint48());
    }

    function getRound(uint256) public pure returns (uint256 price, uint48 timestamp) {
        return (0, 0);
    }

    function decimals() public pure returns (uint8) {
        return 6;
    }
}
