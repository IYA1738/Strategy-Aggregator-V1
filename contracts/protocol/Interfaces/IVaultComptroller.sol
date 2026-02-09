//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IVaultComptroller {
    function getReversedMutex() external view returns (uint8);
}
