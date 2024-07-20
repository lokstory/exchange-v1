// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "src/interfaces/IOracle.sol";

contract Oracle is ChainlinkClient, ConfirmedOwner, IOracle {
    using Chainlink for Chainlink.Request;
    using SafeCast for *;

    uint256 internal immutable _fee;

    bytes32 internal _jobId;
    uint256 internal _roundId;
    mapping(uint256 roundId => Round) internal _rounds;

    constructor(address linkToken, address chainlinkOperator, bytes32 jobId) ConfirmedOwner(msg.sender) {
        _setChainlinkToken(linkToken);
        _setChainlinkOracle(chainlinkOperator);
        _jobId = jobId;
        _fee = (1 * LINK_DIVISIBILITY) / 10;
    }

    /// @inheritdoc IOracle
    function requestNewPrice() external returns (bytes32 requestId) {
        Chainlink.Request memory req = _buildChainlinkRequest(_jobId, address(this), this.fulfill.selector);

        req._add(
            "get",
            "https://api.paraswap.io/prices/?srcToken=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE&destToken=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48&amount=1000000000000000000&side=SELL&network=1&version=6.2"
        );

        req._add("path", "priceRoute,destAmount");
        req._addInt("times", 1);

        return _sendChainlinkRequest(req, _fee);
    }

    /// @inheritdoc IOracle
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }

    /// @inheritdoc IOracle
    function latestPrice() external view returns (uint256) {
        return _rounds[_roundId].price;
    }

    /// @inheritdoc IOracle
    function latestTimestamp() external view returns (uint48) {
        return _rounds[_roundId].timestamp;
    }

    /// @inheritdoc IOracle
    function latestRoundId() external view returns (uint256) {
        return _roundId;
    }

    /// @inheritdoc IOracle
    function getPrice(uint256 roundId) external view returns (uint256) {
        return _rounds[roundId].price;
    }

    /// @inheritdoc IOracle
    function getTimestamp(uint256 roundId) external view returns (uint48) {
        return _rounds[roundId].timestamp;
    }

    /// @inheritdoc IOracle
    function getLatestRound() external view returns (uint256 roundId, uint256 price, uint48 timestamp) {
        roundId = _roundId;
        (price, timestamp) = getRound(roundId);
    }

    /// @inheritdoc IOracle
    function fulfill(bytes32 requestId, uint256 price) public recordChainlinkFulfillment(requestId) {
        uint48 timestamp = block.timestamp.toUint48();
        uint256 roundId = _roundId + 1;

        _roundId = roundId;
        _rounds[roundId] = Round({price: price, timestamp: timestamp});

        emit PriceUpdated(roundId, requestId, price, timestamp);
    }

    /// @inheritdoc IOracle
    function getRound(uint256 roundId) public view returns (uint256 price, uint48 timestamp) {
        Round memory round = _rounds[roundId];
        (price, timestamp) = (round.price, round.timestamp);
    }

    /// @inheritdoc IOracle
    function decimals() public pure returns (uint8) {
        return 6;
    }
}
