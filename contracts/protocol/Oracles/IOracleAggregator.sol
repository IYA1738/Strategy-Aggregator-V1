//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

interface IOracleAggregator {
    function getPriceInUSD(address _asset) external view returns (uint256);
}
