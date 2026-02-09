//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

import "contracts/protocol/Core/Vault/VaultImplStorage.sol";
import "contracts/protocol/Core/Utils/Initializable.sol";
import "contracts/protocol/Core/Vault/ShareBase.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "contracts/protocol/Interfaces/IVaultComptroller.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/external-interfaces/IWETH.sol";

contract VaultImpl is VaultImplStorage, Initializable, ShareBase {
    using SafeERC20 for IERC20;

    event ApprovalToStrategy(address indexed spender, uint256 amount);
    event WithdrawTo(address indexed to, address asset, uint256 amount);

    modifier onlyDuringComptrollerFlow() {
        _checkComptrollerFlow();
        _;
    }

    function _checkComptrollerFlow() private view {
        address comptroller = IRegistry(registry).getComptroller();
        require(msg.sender == comptroller, "VaultImpl: caller is not the comptroller");
        require(
            IVaultComptroller(comptroller).getReversedMutex() == 2,
            "VaultImpl: not during comptroller flow"
        ); //验证反向锁
    }

    function initialize(
        address _denominationAsset,
        address _registry,
        string memory _name,
        string memory _symbol
    ) external Initializer {
        denominationAsset = _denominationAsset;
        registry = _registry;
        _initShares(_name, _symbol);ß
    }

    modifier onlyOwner() {
        require(
            IRegistry(registry).getOwner() == msg.sender,
            "Ownable: caller is not the registryowner"
        );
        _;
    }

    function mint(address _to, uint256 _amount) external onlyDuringComptrollerFlow {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyDuringComptrollerFlow {
        _burn(_from, _amount);
    }

    function withdrawTo(
        address _to,
        address _asset,
        uint256 _amount
    ) external onlyDuringComptrollerFlow {
        IERC20(_asset).safeTransfer(_to, _amount);
        emit WithdrawTo(_to, _asset, _amount);
    }

    function withdrawNativeTo(address _to, uint256 _amount) external onlyDuringComptrollerFlow {
        (bool ok, ) = _to.call{value: _amount}("");
        require(ok, "VaultImpl: native transfer failed");
    }

    //先完成逻辑 后面再风控
    function approveToStrategy(
        address _strategy,
        uint256 _amount
    ) external onlyDuringComptrollerFlow {
        address denomination = denominationAsset;
        IERC20(denomination).approve(_strategy, 0);
        IERC20(denomination).approve(_strategy, _amount);
        emit ApprovalToStrategy(_strategy, _amount);
    }

    function _validateApproval() internal view {}

    receive() external payable {
        if (msg.value == 0) return;
        address weth = IRegistry(registry).getWETH();
        if (msg.sender == weth) return;
        IWETH(weth).deposit{value: msg.value}();
    }
}
