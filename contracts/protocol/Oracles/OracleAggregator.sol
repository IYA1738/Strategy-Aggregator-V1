//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Utils/WadMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/protocol/Oracles/Pyth/IPythPriceFeed.sol";
import "contracts/protocol/Oracles/Chainlink/IChainlinkPriceFeed.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// oracle要有自己的时间锁owner
contract OracleAggregator is Ownable {
    using WadMath for uint256;
    using Math for uint256;

    address private registry;

    enum OracleStatus {
        NORMAL, // 预言机状态正常,其他模块允许正常使用
        DEGRADED_TWAP_ONLY, // 瞬时源不可信, 只允许使用Uniswap TWAP报价
        DEGRADED_PRIMARY_ONLY, // TWAP不可信(TWAP数据不足/流动性太低)， 只允许使用预言机报价
        HALTED, // 预言机状态异常， 其他模块禁用
        FORCED_OK, // 强制放行预言机报价
        FORCED_HALTED // 强制禁用预言机报价
    }

    OracleStatus public status;

    constructor(address _timeLock, address _registry) Ownable(_timeLock) {
        registry = _registry;
        status = OracleStatus.NORMAL;
    }

    function getTriangulatedPrice(
        address base,
        address quote
    ) external view returns (uint256 priceE18) {
        address cl_priceFeed = IRegistry(registry).getChainlinkPriceFeed();
        address pyth_priceFeed = IRegistry(registry).getPythPriceFeed();

        IChainlinkPriceFeed clFeed = IChainlinkPriceFeed(cl_priceFeed);
        IPythPriceFeed pythFeed = IPythPriceFeed(pyth_priceFeed);

        // 返回的价格都是1e18
        uint256 clBasePriceInUSD = clFeed.getPrice(base);
        uint256 pythBasePriceInUSD = pythFeed.getPrice(base);
        uint256 clQuotePriceInUSD = clFeed.getPrice(quote);
        uint256 pythQuotePriceInUSD = pythFeed.getPrice(quote);

        uint256 clPrice1e18 = Math.mulDiv(
            clBasePriceInUSD,
            1e18,
            clQuotePriceInUSD,
            Math.Rounding.Floor
        );

        uint256 pythPrice1e18 = Math.mulDiv(
            pythBasePriceInUSD,
            1e18,
            pythQuotePriceInUSD,
            Math.Rounding.Floor
        );

        uint256 delta = clPrice1e18 > pythPrice1e18
            ? clPrice1e18 - pythPrice1e18
            : pythPrice1e18 - clPrice1e18;
    }

    function getPriceInUSD(address _asset) public view returns (uint256) {
        return 0;
    }

    function getChainlinkQuote(address _asset) public view returns (uint256) {
        return 0;
    }

    function getPythQuote(address _asset) public view returns (uint256) {
        return 0;
    }

    function getUniswapTWAP(address _asset, address _quoteAsset) public view returns (uint256) {
        return 0;
    }

    function getOracleStatus() external view returns (OracleStatus) {
        return status;
    }
}
