//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

interface IChainlinkPriceFeed {
    function getPrice(address _assetA, address _assetB) external view returns (uint256);

    function setPriceFeed(address _assetA, address _assetB, address _priceFeed) external;
}
