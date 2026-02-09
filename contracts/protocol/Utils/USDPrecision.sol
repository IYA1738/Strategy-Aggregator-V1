//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

library USDPrecision {
    uint256 public constant USD_PRECISION = 30;

    function decToUsdPrecision(uint256 _value, uint8 _dec) internal pure returns (uint256) {
        if (_dec == 30) {
            return _value;
        } else if (_dec > 30) {
            return _value * 10 ** (_dec - 30);
        } else {
            return _value / 10 ** (30 - _dec);
        }
    }

    function expoToUsdPrecition(uint256 _value, int32 _expo) internal pure returns (uint256) {
        int256 scaleExp = int256(_expo) + 30;

        if (scaleExp >= 0) {
            return _value * _pow10(uint256(scaleExp));
        } else {
            return _value / _pow10(uint256(-scaleExp));
        }
    }

    // Correctly spelled alias kept for readability in newer code paths.
    function expoToUsdPrecision(uint256 _value, int32 _expo) internal pure returns (uint256) {
        return expoToUsdPrecition(_value, _expo);
    }

    //直接查表, expo不会超过40的
    function _pow10(uint256 n) internal pure returns (uint256) {
        require(n <= 40, "pow10 too large");
        uint256[41] memory T = [
            uint256(1),
            10,
            100,
            1000,
            10000,
            100000,
            1000000,
            10000000,
            100000000,
            1000000000,
            10000000000,
            100000000000,
            1000000000000,
            10000000000000,
            100000000000000,
            1000000000000000,
            10000000000000000,
            100000000000000000,
            1000000000000000000,
            10000000000000000000,
            100000000000000000000,
            1000000000000000000000,
            10000000000000000000000,
            100000000000000000000000,
            1000000000000000000000000,
            10000000000000000000000000,
            100000000000000000000000000,
            1000000000000000000000000000,
            10000000000000000000000000000,
            100000000000000000000000000000,
            1000000000000000000000000000000,
            10000000000000000000000000000000,
            100000000000000000000000000000000,
            1000000000000000000000000000000000,
            10000000000000000000000000000000000,
            100000000000000000000000000000000000,
            1000000000000000000000000000000000000,
            10000000000000000000000000000000000000,
            100000000000000000000000000000000000000,
            1000000000000000000000000000000000000000,
            10000000000000000000000000000000000000000
        ];
        return T[n];
    }
}
