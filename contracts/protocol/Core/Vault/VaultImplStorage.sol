//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Core/Library/types/VaultDataTypes.sol";

abstract contract VaultImplStorage {
    // immutable-like after initialization
    address internal registry;
    address internal denominationAsset;

    // config words (read by VaultComptroller & ValueInterpreter)
    VaultDataTypes.VaultConfig internal vaultConfig;
    VaultDataTypes.VaultRiskConfig internal vaultRiskConfig;

    // fees & accounting
    uint96 internal accruedProtocolFee;
    uint96 internal accruedPerformanceFee;
    uint32 internal lastAccruedManagementFeeTime;

    // bookkeeping
    mapping(address => uint256) internal userDepositTimestamp;
    address[] internal trackedAssets;
    mapping(address => bool) internal isTrackedAsset;
}
