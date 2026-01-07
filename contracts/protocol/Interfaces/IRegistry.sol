//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    function getOwner() external view returns (address);

    function registryVault(address _vault) external;

    function getComptroller() external view returns (address);

    function getWETH() external view returns (address);

    function getOracleAggregatorOwner() external view returns (address);

    function getOracleAggregator() external view returns (address);

    function getPythPriceFeed() external view returns (address);

    function getChainlinkPriceFeed() external view returns (address);

    function isVaultRegistried(address _vault) external view returns (bool);
}
