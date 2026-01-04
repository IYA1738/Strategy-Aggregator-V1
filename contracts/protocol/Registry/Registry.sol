//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Utils/TimeDelayOwnable2Step.sol";

contract Registry is TimeDelayOwnable2Step {
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
}
