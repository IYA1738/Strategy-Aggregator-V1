//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "contracts/protocol/Utils/WadMath.sol";
import "contracts/external-interfaces/Dependencies/TickMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/external-interfaces/IUniswapV3PoolTWAP.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UniswapTWAP {
    using WadMath for uint256;

    mapping(address => mapping(address => address)) public pools;

    event AddPoolPriceSource(address tokenA, address tokenB, address poolAddress);

    function setPoolPriceSource(address tokenA, address tokenB, address poolAddress) external {
        require(tokenA != tokenB, "Identical addresses");
        require(poolAddress != address(0), "Zero address");
        require(poolAddress.code.length > 0, "Not a contract");
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pools[tokenA][tokenB] = poolAddress;
    }

    function _meanTick(address _pool, uint32 _period) internal view returns (int24) {
        require(_period != 0, "Period is zero");
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = _period;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, ) = IUniswapV3PoolMinimal(_pool).observe(secondsAgos);
        int56 delta = tickCumulatives[1] - tickCumulatives[0];
        int56 denom = int56(uint56(_period));
        int56 avgTick = delta / denom; // 丢失的精度部份是预期行为，对齐UniswapV3的计算方式
        if (delta < 0 && (delta % denom != 0)) {
            avgTick--; //向负无穷取整，对齐UniswapV3的meanTick计算方式
        }
        return int24(avgTick);
    }

    function _priceE18FromSqrtPriceX96(
        uint160 sqrtPriceX96,
        uint8 dec0,
        uint8 dec1
    ) internal pure returns (uint256) {
        // 下一表达式等同于 uint256 ratioX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        //  但为了避免溢出，用Math.mulDiv(512)直接除完1 << 192再放到uint256里
        require(dec0 <= 36 && dec1 <= 36, "Unsupported decimals");
        uint256 ratio = Math.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96), 1 << 192);

        if (dec0 >= dec1) {
            ratio = ratio * 10 ** (dec0 - dec1);
        } else {
            ratio = ratio / 10 ** (dec1 - dec0);
        }

        uint256 priceE18 = ratio.toWad(dec1);
        return priceE18;
    }

    // 返回的是tokenA/tokenB的价格，精度为1e18
    // 调用时必须保证tokenA < tokenB的顺序， 否则会失败
    // 返回的价格是 tokenB / tokenA，也就是输入 ETH/USD 时，输出 1 ETH 值多少 USD
    function getTWAP(
        address tokenA,
        address tokenB,
        uint32 period,
        uint128 minTwapLiquidity
    ) external view returns (uint256 priceE18) {
        require(tokenA < tokenB, "ORDER");
        address pool = _validateTwapAvailability(tokenA, tokenB, period, minTwapLiquidity);
        int24 meanTick = _meanTick(pool, period);
        uint8 dec0 = IERC20Metadata(tokenA).decimals();
        uint8 dec1 = IERC20Metadata(tokenB).decimals();
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(meanTick);
        return _priceE18FromSqrtPriceX96(sqrtPriceX96, dec0, dec1);
    }

    function _validateTwapAvailability(
        address tokenA,
        address tokenB,
        uint32 period,
        uint128 minTwapLiquidity
    ) internal view returns (address pool) {
        require(period != 0, "Period is zero");
        pool = pools[tokenA][tokenB];
        require(pool != address(0), "Pool not set for token pair");
        // 检查流动性是否满足要求
        require(
            IUniswapV3PoolMinimal(pool).liquidity() >= minTwapLiquidity,
            "Insufficient TWAP liquidity"
        );
        return pool;
    }
}
