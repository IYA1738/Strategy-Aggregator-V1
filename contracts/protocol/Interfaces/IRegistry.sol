//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IRegistry {
    function getOwner() external view returns (address);

    function registryVault(address _vault) external;

    function registryStrategy(address _strategy) external;

    function getComptroller() external view returns (address);

    function getWETH() external view returns (address);

    function getOracleAggregatorOwner() external view returns (address);

    function getOracleAggregator() external view returns (address);

    function getPythPriceFeed() external view returns (address);

    function getChainlinkPriceFeed() external view returns (address);

    function getFeeManager() external view returns (address);

    function getTreasury() external view returns (address);

    function getValueInterpreter() external view returns (address);

    function getUniswapTWAP() external view returns (address);

    function getUSDAsset() external view returns (address);

    function isVaultRegistered(address _vault) external view returns (bool);

    function isAuthorizedVaultToStrategy(
        address _vault,
        address _strategy
    ) external view returns (bool);
}
