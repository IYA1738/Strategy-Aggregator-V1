//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/protocol/Oracles/Pyth/IPythPriceFeed.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythPriceFeed is IPythPriceFeed {
    IPyth public immutable PYTH;

    mapping(address => bytes32) private _pythPriceIds;

    address public registry;

    uint256 public constant MAX_EXPIRED_TIME = 1000 days;
    uint256 public expiredTime;

    event PythPriceIdSet(address indexed token, bytes32 indexed priceId);
    event ExpiredTimeUpdated(uint256 expiredTime);

    modifier onlyOraclesAggregatorOwner() {
        _checkOraclesAggregatorOwner();
        _;
    }

    function _checkOraclesAggregatorOwner() private view {
        address owner = IRegistry(registry).getOracleAggregatorOwner();
        require(msg.sender == owner, "PythPriceFeed: Caller is not the OraclesAggregator owner");
    }

    modifier onlyOraclesAggregator() {
        _checkOracleAggregator();
        _;
    }

    function _checkOracleAggregator() private view {
        address agg = IRegistry(registry).getOracleAggregator();
        require(msg.sender == agg, "PythPriceFeed: Caller is not the OraclesAggregator");
    }

    constructor(address _registry, address _pyth, uint256 _expiredTime) {
        require(_registry != address(0), "PythPriceFeed: Invalid registry");
        require(_pyth != address(0), "PythPriceFeed: Invalid Pyth address");
        require(_expiredTime <= MAX_EXPIRED_TIME, "PythPriceFeed: Exceeded maximum expired time");

        registry = _registry;
        PYTH = IPyth(_pyth);
        expiredTime = _expiredTime;
    }

    function getPrice(
        address _tokenA
    ) external view override onlyOraclesAggregator returns (uint256 priceE18, uint256 publishTime) {
        bytes32 priceId = _pythPriceIds[_tokenA];
        require(priceId != bytes32(0), "PythPriceFeed: Price ID not set for token");

        PythStructs.Price memory p = PYTH.getPriceNoOlderThan(priceId, expiredTime);
        require(p.price > 0, "PythPriceFeed: Invalid price from Pyth");

        int256 price = p.price;
        int256 expo = int256(p.expo);

        int256 targetExpo = 18 + expo;

        if (targetExpo >= 0) {
            uint256 factor = 10 ** uint256(targetExpo);
            priceE18 = uint256(price) * factor;
        } else {
            uint256 factor = 10 ** uint256(-targetExpo);
            priceE18 = uint256(price) / factor;
        }

        publishTime = p.publishTime;
    }

    function setExpiredTime(uint256 _expiredTime) external onlyOraclesAggregatorOwner {
        require(_expiredTime <= MAX_EXPIRED_TIME, "PythPriceFeed: Exceeded maximum expired time");
        expiredTime = _expiredTime;
        emit ExpiredTimeUpdated(_expiredTime);
    }

    function isPairExist(address _tokenA) external view returns (bool) {
        return _pythPriceIds[_tokenA] != bytes32(0);
    }

    function setPythPriceId(address token, bytes32 priceId) external onlyOraclesAggregatorOwner {
        require(token != address(0), "PythPriceFeed: Invalid token address");
        require(priceId != bytes32(0), "PythPriceFeed: Invalid priceId");
        _pythPriceIds[token] = priceId;
        emit PythPriceIdSet(token, priceId);
    }
}
