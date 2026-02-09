//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Utils/WadMath.sol";
import "contracts/protocol/Oracles/Pyth/IPythPriceFeed.sol";
import "contracts/protocol/Oracles/Chainlink/IChainlinkPriceFeed.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "contracts/protocol/Interfaces/IOracleConfigRegistry.sol";
import "contracts/protocol/Oracles/UniswapTWAP/IUniswapTWAP.sol";
import "contracts/protocol/Utils/USDPrecision.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// oracle要有自己的时间锁owner
contract OracleAggregator is Ownable {
    using WadMath for uint256;
    using Math for uint256;
    using USDPrecision for uint256;

    address private registry;
    // 当前模块和oracleConfigRegistry强相关， 且需要高频与oracleConfigRegistry交互
    // 因此不从registry中读取， 直接存在当前合约下
    // 初始化时先部署ConfigRegistry, 再通过setOracleConfigRegistry设置
    address private oracleConfigRegistry;

    mapping(address => uint256) private manualPriceE18; // token => USD price(1e18)

    uint256 public constant BPS = 10_000;
    uint8 public constant MIN_TWAP_PERIOD = 16;

    event SetOracleConfigRegistry(address oracleConfigRegistry);
    event SetManualPrice(address indexed token, uint256 priceE18);

    event PushTwapPrice(address indexed vault, address base, address quote, uint256 TwapPrice);

    event PushMultiOraclePrice(
        address indexed vault,
        address base,
        address quote,
        uint256 price,
        uint256[] basePrices,
        uint256[] quotePrices
    );

    error InvalidOracleStatus(address _vault, address _base, address _quote);

    constructor(
        address _timeLock,
        address _registry,
        address _oracleConfigRegistry
    ) Ownable(_timeLock) {
        registry = _registry;
        oracleConfigRegistry = _oracleConfigRegistry;
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function getTriangulatedPrice(
        address _vault,
        address _base,
        address _quote,
        uint32 _period,
        Math.Rounding rounding
    ) external view returns (uint256 priceE18) {
        // 先读取oracle config配置看看status是否允许执行
        IOracleConfigRegistry.OracleConfig memory config = IOracleConfigRegistry(
            oracleConfigRegistry
        ).effectiveConfig(_vault, _base); // 如果override了，就给合并后字段
        if (
            config.status == IOracleConfigRegistry.OracleStatus.HALTED ||
            config.status == IOracleConfigRegistry.OracleStatus.FORCED_HALTED
        ) {
            revert InvalidOracleStatus(_vault, _base, _quote);
        }
        uint256[] memory basePrices = new uint256[](3);
        uint256[] memory quotePrices = new uint256[](3);
        uint8 enableSources = config.enabledSources;
        IOracleConfigRegistry.OracleStatus status = config.status;
        if ((enableSources & 1) != 0 && status != IOracleConfigRegistry.OracleStatus.TWAP_ONLY) {
            uint32 chainLinkMaxAge = config.chainLinkMaxAge;
            uint8 basedec;
            uint8 quotedec;
            (basePrices[0], basedec) = getChainlinkQuote(_base, chainLinkMaxAge);
            (quotePrices[0], quotedec) = getChainlinkQuote(_quote, chainLinkMaxAge);
            basePrices[0] = basePrices[0].decToUsdPrecision(basedec); // USD计价，精度30
            quotePrices[0] = quotePrices[0].decToUsdPrecision(quotedec); // USD计价，精度30
        }
        // 得到价格
        if ((enableSources & 2) != 0 && status != IOracleConfigRegistry.OracleStatus.TWAP_ONLY) {
            uint32 pythMaxAge = config.pythMaxAge;
            uint16 pythConfThreshold = config.pythConfThreshold;
            int32 baseExpo;
            int32 quoteExpo;
            (basePrices[1], baseExpo) = getPythQuote(_base, pythMaxAge, pythConfThreshold);
            (quotePrices[1], quoteExpo) = getPythQuote(_quote, pythMaxAge, pythConfThreshold);
            basePrices[1] = basePrices[1].expoToUsdPrecision(baseExpo); // USD计价，精度30
            quotePrices[1] = quotePrices[1].expoToUsdPrecision(quoteExpo); // USD计价，精度30
        }
        // 交叉验证
        // 如果price为0, 在各自的预言机合约中就已经revert了， 不用担心除0问题
        uint16 maxDeviation = config.maxPriceDeviationBPS;
        // mulDiv会先扩展到512位，所以不用担心溢出
        uint256 clPrice = basePrices[0] != 0 && quotePrices[0] != 0
            ? basePrices[0].mulDiv(1e18, quotePrices[0], rounding)
            : 0; //处理到1e18量纲
        uint256 pythPrice = basePrices[1] != 0 && quotePrices[1] != 0
            ? basePrices[1].mulDiv(1e18, quotePrices[1], rounding)
            : 0;
        if (clPrice == 0 && pythPrice == 0) {
            revert InvalidOracleStatus(_vault, _base, _quote);
        }
        if (clPrice == 0) {
            emit PushMultiOraclePrice(_vault, _base, _quote, pythPrice, basePrices, quotePrices);
            return pythPrice;
        }
        if (pythPrice == 0) {
            emit PushMultiOraclePrice(_vault, _base, _quote, clPrice, basePrices, quotePrices);
            return clPrice;
        }
        uint256 priceDelta = clPrice >= pythPrice ? clPrice - pythPrice : pythPrice - clPrice;
        // uint256 deviation = priceDelta / pythPrice; 假设chainlink为主预言机时的校验的写法
        // 不假设任何一个预言机更可信来作为主预言机，采用相对均值误差的写法
        // 等价于deviation = priceDelta / (clPrice + pythPrice) / 2, 但直接先乘2更整数运算友好
        // 乘BPS防小数截断的同时对齐BPS量纲， 如果要更精细的精度的话 再换1E18量纲
        uint256 deviation = priceDelta.mulDiv(2 * BPS, clPrice + pythPrice, Math.Rounding.Ceil);
        if (
            deviation > maxDeviation ||
            config.status == IOracleConfigRegistry.OracleStatus.TWAP_ONLY
        ) {
            IOracleConfigRegistry(oracleConfigRegistry).changeOracleStatus(
                _vault,
                IOracleConfigRegistry.OracleStatus.TWAP_ONLY
            );
            require(_period >= MIN_TWAP_PERIOD, "OracleAggregator: TWAP Period is too short");
            uint256 twapPrice = getUniswapTWAP(_base, _quote, _period, config.minTwapLiquidity);
            emit PushTwapPrice(_vault, _base, _quote, twapPrice);
            return twapPrice;
        } else {
            uint256 price = clPrice.average(pythPrice);
            emit PushMultiOraclePrice(_vault, _base, _quote, price, basePrices, quotePrices);
            return price;
        }
    }

    function getPriceInUSD(address _asset) public view returns (uint256) {
        // try manual override first
        uint256 manual = manualPriceE18[_asset];
        if (manual > 0) return manual;

        address usd = IRegistry(registry).getUSDAsset();
        require(usd != address(0), "OracleAggregator: USD asset not set");
        if (_asset == usd) return 1e18;

        IOracleConfigRegistry.OracleConfig memory config = IOracleConfigRegistry(oracleConfigRegistry)
            .effectiveConfig(address(0), _asset);

        uint256 cl;
        uint256 pyth;
        uint8 sourcesFound;

        if ((config.enabledSources & 1) != 0 && config.status != IOracleConfigRegistry.OracleStatus.TWAP_ONLY) {
            (cl, ) = getChainlinkQuote(_asset, config.chainLinkMaxAge);
            sourcesFound++;
        }
        if ((config.enabledSources & 2) != 0 && config.status != IOracleConfigRegistry.OracleStatus.TWAP_ONLY) {
            (pyth, ) = getPythQuote(_asset, config.pythMaxAge, config.pythConfThreshold);
            sourcesFound++;
        }
        require(sourcesFound > 0, "OracleAggregator: no enabled sources");

        if (sourcesFound == 1 || cl == 0 || pyth == 0) {
            return cl != 0 ? cl : pyth;
        }

        uint256 priceDelta = cl >= pyth ? cl - pyth : pyth - cl;
        uint256 deviation = priceDelta.mulDiv(2 * BPS, cl + pyth, Math.Rounding.Ceil);
        if (deviation > config.maxPriceDeviationBPS || config.status == IOracleConfigRegistry.OracleStatus.TWAP_ONLY) {
            uint32 period = config.twapPeriod;
            require(period >= MIN_TWAP_PERIOD, "OracleAggregator: TWAP period too short");
            uint256 twapPrice = getUniswapTWAP(_asset, usd, period, config.minTwapLiquidity);
            return twapPrice;
        }

        return cl.average(pyth);
    }

    function getChainlinkQuote(
        address _asset,
        uint256 _maxAge
    ) public view returns (uint256, uint8) {
        address clPriceFeed = IRegistry(registry).getChainlinkPriceFeed();
        // rawPrice是1E18的(ChainlinkPriceFeed.sol里处理完了)，但是放去三角定价需要放到1E30
        // preview之类的低精度要求场景可以直接给1E18
        (uint256 rawPrice, uint8 decimals) = IChainlinkPriceFeed(clPriceFeed).getPrice(
            _asset,
            _maxAge
        );
        return (rawPrice, decimals);
    }

    function getPythQuote(
        address _asset,
        uint256 _maxAge,
        uint16 _pythConfThreshold
    ) public view returns (uint256, int32) {
        address pythPriceFeed = IRegistry(registry).getPythPriceFeed();
        return IPythPriceFeed(pythPriceFeed).getPrice(_asset, _maxAge, _pythConfThreshold);
    }

    function getUniswapTWAP(
        address _asset,
        address _quoteAsset,
        uint32 _period,
        uint128 _minLiquidity
    ) public view returns (uint256) {
        address twap = IRegistry(registry).getUniswapTWAP();
        require(twap != address(0), "OracleAggregator: twap not set");
        return IUniswapTWAP(twap).getTWAP(_asset, _quoteAsset, _period, _minLiquidity);
    }

    // ===== admin =====
    function setManualPrice(address _token, uint256 _priceE18) external onlyOwner {
        require(_token != address(0), "OracleAggregator: token=0");
        manualPriceE18[_token] = _priceE18;
        emit SetManualPrice(_token, _priceE18);
    }

    function setOracleConfigRegistry(address _oracleConfigRegistry) external onlyOwner {
        oracleConfigRegistry = _oracleConfigRegistry;
        emit SetOracleConfigRegistry(_oracleConfigRegistry);
    }

    function getOracleConfigRegistry() external view returns (address) {
        return oracleConfigRegistry;
    }
}
