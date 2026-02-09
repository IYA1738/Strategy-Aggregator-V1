//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/protocol/Oracles/Pyth/IPythPriceFeed.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

// 后续记得补上置信度检测

contract PythPriceFeed is IPythPriceFeed {
    IPyth public immutable PYTH;

    mapping(address => bytes32) private _pythPriceIds;

    address public registry;

    uint256 public constant MAX_EXPIRED_TIME = 1 days;
    uint16 public constant BPS = 10_000;

    event PythPriceIdSet(address indexed token, bytes32 indexed priceId);

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

    constructor(address _registry, address _pyth) {
        require(_registry != address(0), "PythPriceFeed: Invalid registry");
        require(_pyth != address(0), "PythPriceFeed: Invalid Pyth address");

        registry = _registry;
        PYTH = IPyth(_pyth);
    }

    function getPrice(
        address _tokenA,
        uint256 _expiredTime,
        uint16 _pythConfThreshold
    ) external view onlyOraclesAggregator override returns (uint256 price, int32 expo) {
        require(_expiredTime <= MAX_EXPIRED_TIME, "PythPriceFeed: Exceeded maximum expired time");

        bytes32 priceId = _pythPriceIds[_tokenA];
        require(priceId != bytes32(0), "PythPriceFeed: Price ID not set for token");

        PythStructs.Price memory p = PYTH.getPriceNoOlderThan(priceId, _expiredTime);
        require(p.price > 0, "PythPriceFeed: Invalid price from Pyth");
        _checkPythConfidence(p.price, p.conf, _pythConfThreshold);
        price = uint256(uint64(p.price));
        expo = p.expo;
    }

    function _checkPythConfidence(
        int64 _price,
        uint64 _conf,
        uint16 _pythConfThreshold
    ) private view {
        require(
            // price强转uint64不会溢出, 根据上下文可保证 0 < _price < int64.max < uint64.max
            (_conf * BPS) / uint64(_price) <= _pythConfThreshold,
            "PythPriceFeed: Price confidence too low"
        );
    }

    function isPairExist(address _tokenA) external view override returns (bool) {
        return _pythPriceIds[_tokenA] != bytes32(0);
    }

    function setPythPriceId(address token, bytes32 priceId) external override onlyOraclesAggregatorOwner {
        require(token != address(0), "PythPriceFeed: Invalid token address");
        require(priceId != bytes32(0), "PythPriceFeed: Invalid priceId");
        _pythPriceIds[token] = priceId;
        emit PythPriceIdSet(token, priceId);
    }
}
