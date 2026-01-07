//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

abstract contract VaultImplStorage {
    address internal registry;
    address internal denominationAsset;

    mapping(address => uint256) internal userDepositTimestamp;
}
