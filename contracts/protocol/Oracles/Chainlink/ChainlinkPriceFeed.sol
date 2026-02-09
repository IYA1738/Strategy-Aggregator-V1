//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "contracts/protocol/Oracles/Chainlink/IChainlinkPriceFeed.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "contracts/protocol/Utils/WadMath.sol";

contract ChainLinkPriceFeed is IChainlinkPriceFeed {
    using WadMath for uint256;
    mapping(address => address) public priceFeeds; // baseToken => priceFeedAddress

    address public registry;

    uint256 public constant MAX_EXPIRED_TIME = 1000 days;

    event PriceFeedUpdated(address indexed token, address indexed priceFeed);
    event ExpiredTimeUpdated(uint256 expiredTime);

    modifier onlyOraclesAggregatorOwner() {
        _checkOraclesAggregatorOwner();
        _;
    }

    function _checkOraclesAggregatorOwner() private view {
        address owner = IRegistry(registry).getOracleAggregatorOwner();
        require(
            msg.sender == owner,
            "ChainLinkPriceFeed: Caller is not the OraclesAggregator owner"
        );
    }

    modifier onlyOraclesAggregator() {
        _checkOracleAggregator();
        _;
    }

    function _checkOracleAggregator() private view {
        address agg = IRegistry(registry).getOracleAggregator();
        require(msg.sender == agg, "ChainLinkPriceFeed: Caller is not the OraclesAggregator");
    }

    constructor(address _registry) {
        require(_registry != address(0), "ChainLinkPriceFeed: Invalid registry");
        registry = _registry;
    }

    function getPrice(
        address _tokenA,
        uint256 _expiredTime
    ) external view override onlyOraclesAggregator returns (uint256, uint8) {
        address feed = priceFeeds[_tokenA];
        require(feed != address(0), "ChainLinkPriceFeed: Price feed not set for token");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        require(price > 0, "ChainLinkPriceFeed: Invalid price data");
        require(
            block.timestamp - updatedAt <= _expiredTime,
            "ChainLinkPriceFeed: Price data is expired"
        );

        return (uint256(price).toWad(priceFeed.decimals()), 18); // normalized to 1E18, report 18
    }

    function setPriceFeed(address _tokenA, address _priceFeed) external override onlyOraclesAggregatorOwner {
        require(_tokenA != address(0), "ChainLinkPriceFeed: Invalid token");
        require(_priceFeed != address(0), "ChainLinkPriceFeed: Invalid priceFeed");
        require(
            priceFeeds[_tokenA] == address(0),
            "ChainLinkPriceFeed: Price feed already set for token"
        );

        priceFeeds[_tokenA] = _priceFeed;
        emit PriceFeedUpdated(_tokenA, _priceFeed);
    }

    function isPairExist(address _tokenA) external view override returns (bool) {
        return priceFeeds[_tokenA] != address(0);
    }
}
