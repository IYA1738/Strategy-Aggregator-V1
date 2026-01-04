//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

abstract contract Proxiable {
    bytes32 public immutable PROXYABLE_UUID = keccak256("IYA.StrategyUpgradable.V1");

    function UUID() external view returns (bytes32) {
        return PROXYABLE_UUID;
    }
}
