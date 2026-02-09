//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

interface Ownable_Minimun {
    function getOwner() external view returns (address);
}

contract OracleConfigRegistry {
    uint16 constant OF_STATUS = 1 << 0;
    uint16 constant OF_SOURCES = 1 << 1;
    uint16 constant OF_MAX_DEV = 1 << 2;
    uint16 constant OF_TWAP = 1 << 3;
    uint16 constant OF_CL_AGE = 1 << 4;
    uint16 constant OF_PY_AGE = 1 << 5;
    uint16 constant OF_MIN_MANIPULATION_COST = 1 << 6;
    uint16 constant OF_PYTH_CONF_THRESHOLD = 1 << 7;
    uint16 constant OF_MIN_TWAP_LIQUIDITY = 1 << 8;

    address internal registry;
    // 当前模块和oracleAggregator强相关， 且需要高频与oracleAggregator交互
    // 因此不从registry中读取， 直接存在当前合约下
    address internal oracleAggregator;

    modifier onlyOracleAggregatorOwner() {
        _checkOracleAggregatorOwner();
        _;
    }

    function _checkOracleAggregatorOwner() internal view {
        require(
            msg.sender == Ownable_Minimun(oracleAggregator).getOwner(),
            "Ownable: caller is not the owner"
        );
    }

    constructor(address _registry, address _oracleAggregator) {
        registry = _registry;
        oracleAggregator = _oracleAggregator;
    }

    event SetVaultOracleConfig(address vault);
    event SetTokenOracleOverride(address vault, address token);

    enum OracleStatus {
        NORMAL, // 预言机状态正常,其他模块允许正常使用
        TWAP_ONLY, // 瞬时源不可信, 只允许使用Uniswap TWAP报价
        PRIMARY_ONLY, // TWAP不可信(TWAP数据不足/流动性太低)， 只允许使用预言机报价
        HALTED, // 预言机状态异常， 其他模块禁用
        FORCED_OK, // 强制放行预言机报价
        FORCED_HALTED // 强制禁用预言机报价
    }

    struct OracleConfig {
        // slot 0 已经用了144 bits
        OracleStatus status; //uint8
        uint8 enabledSources; // CL=1, PYTH=2, TWAP=4
        uint16 maxPriceDeviationBPS;
        uint32 twapPeriod;
        uint32 chainLinkMaxAge;
        uint32 pythMaxAge;
        uint16 pythConfThreshold;
        // slot 1
        uint128 minTwapLiquidity; // TWAP报价的最小流动性要求
    }

    struct TokenOracleOverride {
        // slot 0 已经用了160 bits
        uint16 overrideFlags; // 哪些字段覆盖
        uint8 enabledSources; // CL=1, PYTH=2, TWAP=4
        OracleStatus status; // 仅当 overrideFlags 包含 STATUS 位时生效
        uint16 maxDevBps;
        uint32 twapPeriod;
        uint32 clMaxAge;
        uint32 pythMaxAge;
        uint16 pythConfThreshold;
        // Slot 1
        uint128 minTwapLiquidity; // TWAP报价的最小流动性要求
    }

    // Vault => Default Config
    mapping(address => OracleConfig) internal vaultOracleConfigs;
    // Vault => Token => Override
    mapping(address => mapping(address => TokenOracleOverride)) internal vaultTokenOracleOverrides;

    function effectiveConfig(
        address _vault,
        address _token
    ) external view returns (OracleConfig memory effective) {
        TokenOracleOverride memory o = vaultTokenOracleOverrides[_vault][_token];
        OracleConfig memory base = vaultOracleConfigs[_vault];

        uint16 flags = o.overrideFlags;
        if (flags == 0) return base;

        // 根据flags的值来决定使用override还是base的值
        // 使用位运算替代多个If判断来节省Gas
        effective.status = (flags & OF_STATUS) != 0 ? o.status : base.status;
        effective.enabledSources = (flags & OF_SOURCES) != 0
            ? o.enabledSources
            : base.enabledSources;
        effective.maxPriceDeviationBPS = (flags & OF_MAX_DEV) != 0
            ? o.maxDevBps
            : base.maxPriceDeviationBPS;
        effective.twapPeriod = (flags & OF_TWAP) != 0 ? o.twapPeriod : base.twapPeriod;
        effective.chainLinkMaxAge = (flags & OF_CL_AGE) != 0 ? o.clMaxAge : base.chainLinkMaxAge;
        effective.pythMaxAge = (flags & OF_PY_AGE) != 0 ? o.pythMaxAge : base.pythMaxAge;
        effective.minTwapLiquidity = (flags & OF_MIN_TWAP_LIQUIDITY) != 0
            ? o.minTwapLiquidity
            : base.minTwapLiquidity;
        effective.pythConfThreshold = (flags & OF_PYTH_CONF_THRESHOLD) != 0
            ? o.pythConfThreshold
            : base.pythConfThreshold;

        return effective;
    }

    function setVaultOracleConfig(
        address _vault,
        OracleConfig memory _config
    ) public onlyOracleAggregatorOwner {
        require(_config.enabledSources <= 7, "OracleConfigRegistry: invalid sources");
        vaultOracleConfigs[_vault] = _config;
        emit SetVaultOracleConfig(_vault);
    }

    function deleteVaultOracleConfig(address _vault) public onlyOracleAggregatorOwner {
        delete vaultOracleConfigs[_vault];
        emit SetVaultOracleConfig(_vault);
    }

    function getVaultOracleConfig(address _vault) external view returns (OracleConfig memory) {
        return vaultOracleConfigs[_vault];
    }

    function setTokenOracleOverride(
        address _vault,
        address _token,
        TokenOracleOverride memory _override
    ) external onlyOracleAggregatorOwner {
        require(_override.enabledSources <= 7, "OracleConfigRegistry: invalid sources");
        vaultTokenOracleOverrides[_vault][_token] = _override;
        emit SetTokenOracleOverride(_vault, _token);
    }

    function deleteTokenOracleOverride(
        address _vault,
        address _token
    ) public onlyOracleAggregatorOwner {
        delete vaultTokenOracleOverrides[_vault][_token];
        emit SetTokenOracleOverride(_vault, _token);
    }

    function getTokenOracleOverride(
        address _vault,
        address _token
    ) external view returns (TokenOracleOverride memory) {
        return vaultTokenOracleOverrides[_vault][_token];
    }

    // return true就是要override
    function hasTokenOracleOverride(address _vault, address _token) external view returns (bool) {
        return vaultTokenOracleOverrides[_vault][_token].overrideFlags != 0;
    }

    // allow oracle aggregator owner to adjust status for a given vault
    function changeOracleStatus(address _vault, OracleStatus _status) external onlyOracleAggregatorOwner {
        vaultOracleConfigs[_vault].status = _status;
    }
}
