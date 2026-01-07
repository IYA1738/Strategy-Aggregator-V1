//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Utils/TimeDelayOwnable2Step.sol";
import "contracts/protocol/Registry/OracleConfigRegistry.sol";

interface IOracleAggregatorOwner {
    function getOwner() external view returns (address);
}

contract Registry is TimeDelayOwnable2Step, OracleConfigRegistry {
    mapping(address => bool) private registriedVaults;
    mapping(address => bool) private registriedStrategies;

    mapping(address => mapping(address => bool)) private vaultToStrategies;

    address private timeLock;

    address private vaultFactory;

    address private oracleAggregator;
    address private feeManager;
    address private treasury;
    address private valueInterpreter;

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

        __init_Ownable(msg.sender, 1 hours);
    }

    event RegistryVault(address vault, address provider);

    // 只能由vaultFactory调用注册vault
    function registryVault(address _vault) external onlyFactory {
        require(!registriedVaults[_vault], "Registry: vault already registried");
        registriedVaults[_vault] = true;
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

    function setVaultOracleConfig(
        address _vault,
        OracleConfig memory _config
    ) external onlyOracleAggregatorOwner {
        _setVaultOracleConfig(_vault, _config);
    }

    function getVaultOracleConfig(address _vault) external view returns (OracleConfig memory) {
        return _getVaultOracleConfig(_vault);
    }

    function setTokenOracleOverride(
        address _vault,
        address _token,
        TokenOracleOverride memory _override
    ) external onlyOracleAggregatorOwner {
        _setTokenOracleOverride(_vault, _token, _override);
    }

    function getTokenOracleOverride(
        address _vault,
        address _token
    ) external view returns (TokenOracleOverride memory) {
        return _getTokenOracleOverride(_vault, _token);
    }

    function hasTokenOracleOverride(address _vault, address _token) external view returns (bool) {
        return _hasTokenOracleOverride(_vault, _token);
    }

    // ====== getter ======
    function getOracleAggregator() external view returns (address) {
        return oracleAggregator;
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
}
