//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IValueInterpreter {
    /// @notice Return vault NAV in 18-decimal precision.
    function getVaultNAV(address _vault) external view returns (uint256 navE18);
}
