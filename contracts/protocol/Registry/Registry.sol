//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Utils/TimeDelayOwnable2Step.sol";

interface IOracleAggregatorOwner {
    function getOwner() external view returns (address);
}

contract Registry is TimeDelayOwnable2Step {
    mapping(address => bool) private registriedVaults;
    mapping(address => bool) private registriedStrategies;

    mapping(address => mapping(address => bool)) private vaultToStrategies;

    address private timeLock;

    address private vaultFactory;

    address private oracleAggregator;
    address private oracleAggregatorOwner;
    address private feeManager;
    address private treasury;
    address private valueInterpreter;
    address private chainlinkPriceFeed;
    address private pythPriceFeed;
    address private comptroller;
    address private weth;
    address private uniswapTWAP;
    address private usdAsset;

    event RegistryVault(address vault);
    event UnRegistryVault(address vault);
    event SetOracleAggregator(address oracleAggregator);
    event SetFeeManager(address feeManager);
    event SetTreasury(address treasury);
    event SetValueInterpreter(address valueInterpreter);
    event AuthorizeVaultToStrategy(address indexed vault, address strategy);
    event UnauthorizeVaultToStrategy(address indexed vault, address strategy);

    modifier onlyFactory() {
        require(msg.sender == vaultFactory, "Ownable: caller is not the factory");
        _;
    }

    modifier onlyTimeLock() {
        require(msg.sender == timeLock, "Ownable: caller is not the timelock");
        _;
    }

    modifier onlyOracleAggregatorOwner() {
        _checkOracleAggregatorOwnerCall();
        _;
    }

    function _checkOracleAggregatorOwnerCall() private view {
        require(
            msg.sender == IOracleAggregatorOwner(oracleAggregator).getOwner(),
            "Registry: caller is not the oracle aggregator owner"
        );
    }

    constructor(
        address _vaultFactory,
        address _oracleAggregator,
        address _feeManager,
        address _treasury,
        address _valueInterpreter
    ) {
        vaultFactory = _vaultFactory;
        oracleAggregator = _oracleAggregator;
        feeManager = _feeManager;
        treasury = _treasury;
        valueInterpreter = _valueInterpreter;
        timeLock = msg.sender;

        __init_Ownable(msg.sender, 1 hours);
    }

    // 只能由vaultFactory调用注册vault
    function registryVault(address _vault) external onlyFactory {
        require(!registriedVaults[_vault], "Registry: vault already registried");
        registriedVaults[_vault] = true;
    }

    function registryStrategy(address _strategy) external onlyOwner {
        require(!registriedStrategies[_strategy], "Registry: strategy already registried");
        registriedStrategies[_strategy] = true;
    }

    function unRegistryVault(address _vault) external onlyOwner {
        registriedVaults[_vault] = false;
    }

    function authorizeVaultToStrategy(address _vault, address _strategy) external onlyOwner {
        require(registriedVaults[_vault], "Registry: vault not registried");
        require(registriedStrategies[_strategy], "Registry: strategy not registried");
        vaultToStrategies[_vault][_strategy] = true;
    }

    // 取消权限不是敏感操作 去掉检查节省一点gas
    function unauthorizeVaultToStrategy(address _vault, address _strategy) external onlyOwner {
        vaultToStrategies[_vault][_strategy] = false;
    }

    // ===== governance ======
    function setOracleAggregator(address _oracleAggregator) external onlyTimeLock {
        oracleAggregator = _oracleAggregator;
        emit SetOracleAggregator(_oracleAggregator);
    }

    function setOracleAggregatorOwner(address _oracleAggregatorOwner) external onlyTimeLock {
        oracleAggregatorOwner = _oracleAggregatorOwner;
    }

    function setComptroller(address _comptroller) external onlyTimeLock {
        comptroller = _comptroller;
    }

    function setWETH(address _weth) external onlyTimeLock {
        weth = _weth;
    }

    function setUniswapTWAP(address _uniswapTWAP) external onlyTimeLock {
        uniswapTWAP = _uniswapTWAP;
    }

    function setUSDAsset(address _usdAsset) external onlyTimeLock {
        usdAsset = _usdAsset;
    }

    function setChainlinkPriceFeed(address _chainlinkPriceFeed) external onlyTimeLock {
        chainlinkPriceFeed = _chainlinkPriceFeed;
    }

    function setPythPriceFeed(address _pythPriceFeed) external onlyTimeLock {
        pythPriceFeed = _pythPriceFeed;
    }

    function setFeeManager(address _feeManager) external onlyTimeLock {
        feeManager = _feeManager;
        emit SetFeeManager(_feeManager);
    }

    function setTreasury(address _treasury) external onlyTimeLock {
        treasury = _treasury;
        emit SetTreasury(_treasury);
    }

    function setValueInterpreter(address _valueInterpreter) external onlyTimeLock {
        valueInterpreter = _valueInterpreter;
        emit SetValueInterpreter(_valueInterpreter);
    }

    // ====== getter ======
    function getOracleAggregator() external view returns (address) {
        return oracleAggregator;
    }

    function getOracleAggregatorOwner() external view returns (address) {
        return oracleAggregatorOwner;
    }

    function getComptroller() external view returns (address) {
        return comptroller;
    }

    function getWETH() external view returns (address) {
        return weth;
    }

    function getChainlinkPriceFeed() external view returns (address) {
        return chainlinkPriceFeed;
    }

    function getPythPriceFeed() external view returns (address) {
        return pythPriceFeed;
    }

    function getUniswapTWAP() external view returns (address) {
        return uniswapTWAP;
    }

    function getUSDAsset() external view returns (address) {
        return usdAsset;
    }

    function getFeeManager() external view returns (address) {
        return feeManager;
    }

    function getTreasury() external view returns (address) {
        return treasury;
    }

    function getValueInterpreter() external view returns (address) {
        return valueInterpreter;
    }

    function isVaultRegistered(address _vault) external view returns (bool) {
        return registriedVaults[_vault];
    }

    function isAuthorizedVaultToStrategy(
        address _vault,
        address _strategy
    ) external view returns (bool) {
        return vaultToStrategies[_vault][_strategy];
    }
}
