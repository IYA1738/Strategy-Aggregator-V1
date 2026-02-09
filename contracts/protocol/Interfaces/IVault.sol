//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "contracts/protocol/Core/Library/types/VaultDataTypes.sol";

interface IVault {
    function getVaultConfig() external view returns (VaultDataTypes.VaultConfig memory);

    function getVaultRiskConfig() external view returns (VaultDataTypes.VaultRiskConfig memory);

    function getDenominationAsset() external view returns (address);

    function totalSupply() external view returns (uint256);

    function trackedAssets() external view returns (address[] memory);

    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    function withdrawTo(address _to, address _asset, uint256 _amount) external;

    function withdrawNativeTo(address _to, uint256 _amount) external;

    function updateAccuredFee(uint256 _feeAmount) external;

    function setUserDepositTimestamp(address _user, uint256 _timestamp) external;

    function getUserDepositTimestamp(address _user) external view returns (uint256);

    function authorizeStrategySpending(address _strategy, uint256 _amount) external;
}
