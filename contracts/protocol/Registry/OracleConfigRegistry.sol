//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

abstract contract OracleConfigRegistry {
    uint16 constant OF_STATUS = 1 << 0;
    uint16 constant OF_SOURCES = 1 << 1;
    uint16 constant OF_MAX_DEV = 1 << 2;
    uint16 constant OF_TWAP = 1 << 3;
    uint16 constant OF_CL_AGE = 1 << 4;
    uint16 constant OF_PY_AGE = 1 << 5;
    uint16 constant OF_MIN_MANIPULATION_COST = 1 << 6;
    uint16 constant OF_MIN_TWAP_LIQUIDITY = 1 << 7;

    enum OracleStatus {
        NORMAL, // 预言机状态正常,其他模块允许正常使用
        DEGRADED_TWAP_ONLY, // 瞬时源不可信, 只允许使用Uniswap TWAP报价
        DEGRADED_PRIMARY_ONLY, // TWAP不可信(TWAP数据不足/流动性太低)， 只允许使用预言机报价
        HALTED, // 预言机状态异常， 其他模块禁用
        FORCED_OK, // 强制放行预言机报价
        FORCED_HALTED // 强制禁用预言机报价
    }

    struct OracleConfig {
        // slot 0 已经用了128 bits
        OracleStatus status; //uint8
        uint8 enabledSources; // CL=1, PYTH=2, TWAP=4
        uint16 maxPriceDeviationBPS;
        uint32 twapPeriod;
        uint32 chainLinkMaxAge;
        uint32 pythMaxAge;
        // slot 1
        uint128 minManipulationCostE18; // 预言机防操纵的最小成本要求
        uint128 minTwapLiquidity; // TWAP报价的最小流动性要求
    }

    struct TokenOracleOverride {
        // slot 0 已经用了144 bits
        uint16 overrideFlags; // 哪些字段覆盖
        uint8 enabledSources; // CL=1, PYTH=2, TWAP=4
        OracleStatus status; // 仅当 overrideFlags 包含 STATUS 位时生效
        uint16 maxDevBps;
        uint32 twapPeriod;
        uint32 clMaxAge;
        uint32 pythMaxAge;
        // Slot 1
        uint128 minManipulationCostE18; // 预言机防操纵的最小成本要求
        uint128 minTwapLiquidity; // TWAP报价的最小流动性要求
    }

    mapping(address => OracleConfig) internal vaultOracleConfigs;
    mapping(address => mapping(address => TokenOracleOverride)) internal vaultTokenOracleOverrides;

    function _effectiveConfig(
        address _vault,
        address _token
    ) internal view returns (OracleConfig memory effective) {
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
        effective.minManipulationCostE18 = (flags & OF_MIN_MANIPULATION_COST) != 0
            ? o.minManipulationCostE18
            : base.minManipulationCostE18;
        effective.minTwapLiquidity = (flags & OF_MIN_TWAP_LIQUIDITY) != 0
            ? o.minTwapLiquidity
            : base.minTwapLiquidity;

        return effective;
    }

    function _setVaultOracleConfig(address _vault, OracleConfig memory _config) internal {
        vaultOracleConfigs[_vault] = _config;
    }

    function _getVaultOracleConfig(address _vault) internal view returns (OracleConfig memory) {
        return vaultOracleConfigs[_vault];
    }

    function _setTokenOracleOverride(
        address _vault,
        address _token,
        TokenOracleOverride memory _override
    ) internal {
        vaultTokenOracleOverrides[_vault][_token] = _override;
    }

    function _getTokenOracleOverride(
        address _vault,
        address _token
    ) internal view returns (TokenOracleOverride memory) {
        return vaultTokenOracleOverrides[_vault][_token];
    }

    // return true就是要override
    function _hasTokenOracleOverride(address _vault, address _token) internal view returns (bool) {
        return vaultTokenOracleOverrides[_vault][_token].overrideFlags != 0;
    }
}
