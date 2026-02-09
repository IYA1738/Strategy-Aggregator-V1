//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IOracleConfigRegistry {
    enum OracleStatus {
        NORMAL,
        TWAP_ONLY,
        PRIMARY_ONLY,
        HALTED,
        FORCED_OK,
        FORCED_HALTED
    }

    struct OracleConfig {
        OracleStatus status;
        uint8 enabledSources; // CL=1, PYTH=2, TWAP=4
        uint16 maxPriceDeviationBPS;
        uint32 twapPeriod;
        uint32 chainLinkMaxAge;
        uint32 pythMaxAge;
        uint16 pythConfThreshold;
        uint128 minTwapLiquidity;
    }

    struct TokenOracleOverride {
        uint16 overrideFlags;
        uint8 enabledSources;
        OracleStatus status;
        uint16 maxDevBps;
        uint32 twapPeriod;
        uint32 clMaxAge;
        uint32 pythMaxAge;
        uint16 pythConfThreshold;
        uint128 minTwapLiquidity;
    }

    function effectiveConfig(
        address _vault,
        address _token
    ) external view returns (OracleConfig memory effective);

    function getVaultOracleConfig(address _vault) external view returns (OracleConfig memory);

    function getTokenOracleOverride(
        address _vault,
        address _token
    ) external view returns (TokenOracleOverride memory);

    function hasTokenOracleOverride(address _vault, address _token) external view returns (bool);

    function changeOracleStatus(address _vault, OracleStatus _status) external;

    function setVaultOracleConfig(address _vault, OracleConfig calldata _config) external;

    function deleteVaultOracleConfig(address _vault) external;

    function setTokenOracleOverride(
        address _vault,
        address _token,
        TokenOracleOverride calldata _override
    ) external;

    function deleteTokenOracleOverride(address _vault, address _token) external;
}
