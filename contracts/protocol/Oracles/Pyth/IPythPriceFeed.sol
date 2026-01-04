//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPythPriceFeed {
    function getPrice(address tokenA) external view returns (uint256 priceE18, uint256 publishTime);

    function isPairExist(address tokenA) external view returns (bool);

    function setPythPriceId(address token, bytes32 priceId) external;

    function setExpiredTime(uint256 expiredTime) external;

    function expiredTime() external view returns (uint256);

    function registry() external view returns (address);
}
