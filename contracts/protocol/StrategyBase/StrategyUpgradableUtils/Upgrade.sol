//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/StrategyBase/StrategyUpgradableUtils/Proxiable.sol";

abstract contract Upgrade is Proxiable {
    // 鉴权
    function authorizeToUpgrade() internal {}

    // 校验
    function upgradeTo(address _newImplementation) external {
        _upgradeTo(_newImplementation);
    }

    // 执行
    function _upgradeTo(address _newImplementation) internal {}
}
