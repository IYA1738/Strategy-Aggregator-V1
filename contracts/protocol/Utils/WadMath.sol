//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

library WadMath {
    function toWad(uint256 _value, uint256 _decimals) internal pure returns (uint256) {
        if (_decimals == 18) {
            return _value;
        } else if (_decimals > 18) {
            return _value / 10 ** (_decimals - 18);
        } else {
            return _value * 10 ** (18 - _decimals);
        }
    }
}
