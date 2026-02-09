//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPythPriceFeed {
    function getPrice(
        address _tokenA,
        uint256 _expiredTime,
        uint16 _pythConfThreshold
    ) external view returns (uint256 price, int32 expo);

    function isPairExist(address _tokenA) external view returns (bool);

    function setPythPriceId(address token, bytes32 priceId) external;
}
