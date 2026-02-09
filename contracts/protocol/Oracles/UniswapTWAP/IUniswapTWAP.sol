//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IUniswapTWAP {
    function getTWAP(
        address tokenA,
        address tokenB,
        uint32 period,
        uint128 minTwapLiquidity
    ) external view returns (uint256 priceE18);
}
