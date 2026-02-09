//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChainlinkPriceFeed {
    function getPrice(
        address _tokenA,
        uint256 _maxAge
    ) external view returns (uint256 priceE18, uint8 normalizedDecimals);

    function setPriceFeed(address tokenA, address priceFeed) external;

    function isPairExist(address tokenA) external view returns (bool);

    function priceFeeds(address tokenA) external view returns (address);

    function registry() external view returns (address);
}
