// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IOracle {
    struct Round {
        uint256 price;
        uint48 timestamp;
    }

    /// @notice Emitted when the price is updated
    /// @param roundId The ID of the round for which the price is updated
    /// @param requestId The request ID for the price update fulfillment
    /// @param price The updated price
    /// @param timestamp The timestamp of the updated price
    event PriceUpdated(uint256 roundId, bytes32 indexed requestId, uint256 price, uint48 timestamp);

    /// @notice Requests an update for the new round of the price
    function requestNewPrice() external returns (bytes32 requestId);

    /// @notice Updates the price; intended to be called by the Chainlink operator
    function fulfill(bytes32 requestId, uint256 price) external;

    /// @notice Withdraws LINK tokens to the contract owner
    function withdrawLink() external;

    /// @notice Gets the price of the latest round
    function latestPrice() external view returns (uint256);

    /// @notice Gets the timestamp of the latest round
    function latestTimestamp() external view returns (uint48);

    /// @notice Gets the ID of the latest round
    function latestRoundId() external view returns (uint256);

    /// @notice Gets the price for the specified `roundId`
    function getPrice(uint256 roundId) external view returns (uint256);

    /// @notice Gets the timestamp for the specified `roundId`
    function getTimestamp(uint256 roundId) external view returns (uint48);

    /// @notice Gets the round ID, price, and timestamp of the latest round
    function getLatestRound() external view returns (uint256 roundId, uint256 price, uint48 timestamp);

    /// @notice Gets the price and timestamp for the specified `roundId`
    function getRound(uint256 roundId) external view returns (uint256 price, uint48 timestamp);

    /// @notice Gets the number of decimal places for prices
    function decimals() external view returns (uint8);
}
