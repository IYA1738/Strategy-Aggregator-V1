//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @dev Simple address provider interface. Concrete implementation can evolve later.
 */
interface IVaultAddressProvider {
    function getRegistry() external view returns (address);

    function getComptroller() external view returns (address);

    function getVaultFactory() external view returns (address);
}
