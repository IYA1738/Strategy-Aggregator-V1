//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

abstract contract OracleConfigRegistry {
    enum OracleStatus {
        NORMAL, // 预言机状态正常,其他模块允许正常使用
        DEGRADED_TWAP_ONLY, // 瞬时源不可信, 只允许使用Uniswap TWAP报价
        DEGRADED_PRIMARY_ONLY, // TWAP不可信(TWAP数据不足/流动性太低)， 只允许使用预言机报价
        HALTED, // 预言机状态异常， 其他模块禁用
        FORCED_OK, // 强制放行预言机报价
        FORCED_HALTED // 强制禁用预言机报价
    }

    struct OracleConfig {
        OracleStatus status;
        uint16 maxPriceDeviationBPS;
        uint32 twapPeriod;
        uint32 chainLinkMaxAge;
        uint32 pythMaxAge;
    }

    struct TokenOracleOverride {
        uint16 overrideFlags; // 哪些字段覆盖
        uint8 enabledSources; // CL=1, PYTH=2, TWAP=4
        OracleStatus status; // 仅当 overrideFlags 包含 STATUS 位时生效
        uint16 maxDevBps;
        uint32 twapPeriod;
        uint32 clMaxAge;
        uint32 pythMaxAge;
    }
}
