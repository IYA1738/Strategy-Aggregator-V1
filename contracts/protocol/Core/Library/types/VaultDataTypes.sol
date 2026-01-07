//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

library VaultDataTypes {
    struct VaultData {
        VaultConfig config;
        VaultRiskConfig riskConfig;
        uint96 accruedProtocolFee;
        uint96 accruedPerformanceFee;
        uint32 lastAccruedManagementFeeTime;
    }

    struct VaultConfig {
        // bit 0~15: depositFeeRate
        // bit 16~31: withdrawFeeRate
        uint256 word;
    }

    struct VaultRiskConfig {
        // bit 0~15: MinIdleRate // 账面可用资产必须在CAP的百分之几以上
        // bit 16~31: MaxDeployFundRate // 单次最高部署给一个策略的资金不能超过总资产的百分之几，低风险策略可以放宽到100%
        // bit 32~71: CoolDown // deposit与withdraw的冷却时间，单位秒, uint40
        // bit 72 isActive // vault是否激活
        // bit 73 isPaused // vault是否暂停
        // bit 74 isReentrantGuard
        // bit 75 ~ 170 minDepositAmountE18 // 最小存款金额，单位18位精度
        uint256 word;
    }
}
