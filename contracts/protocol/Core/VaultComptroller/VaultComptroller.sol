//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "contracts/protocol/Utils/TimeDelayOwnable2Step.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "contracts/protocol/Core/Library/logics/VaultDataBitParse.sol";
import "contracts/protocol/Core/Library/types/VaultDataTypes.sol";
import "contracts/protocol/Utils/WadMath.sol";
import "contracts/protocol/Interfaces/IValueInterpreter.sol";
import "contracts/external-interfaces/IWETH.sol";
import "contracts/protocol/Interfaces/IVault.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// 用户交互入口 / entry point
// 暂停机制为团队多签owner可以有有限次的暂停合约操作的权限，单次暂停时间24小时，防止黑客攻击时用户资产被大量转移
// 团队多签的暂停次数增减基于社区治理投票决定

// 需要注意NAV计算, 这里是非常直接的攻击面
// 不能出现BalancerV2的账本先算，资产后补的情况
// 任何未结算的资产都不能引入到NAV计算中, 包括在外未结算状态，未结算应收款等
// 但是未结算负债是一定要引入结算的，必须减去所有负债, 且必须在负债的同时就计入负债端，否则会出现时间套利和转嫁fee给其他人

// 在执行任何涉及结算的操作前，必须校验用户余额是否充足完成所有操作，尤其是Batch类操作要先看所需的钱是否足够做Batch，不能像BalancerV2一样允许先计算后转账
contract VaultComptroller is TimeDelayOwnable2Step {
    using VaultDataBitParse for uint256;
    using WadMath for uint256;
    using Math for uint256;
    using SafeERC20 for IERC20;

    address public immutable REGISTRY;
    address internal constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint8 internal reentrancyGuard;

    event Deposit(
        address indexed user,
        address indexed vault,
        address asset,
        uint256 amount,
        uint256 sharesOut
    );

    event RedeemInKind(
        address indexed vault,
        address indexed caller,
        address indexed recipient,
        uint256 sharesAmount,
        address[] payoutAssets,
        uint256[] payoutAmount
    );

    modifier nonReentrant() {
        _checkReentrant();
        _;
        reentrancyGuard = 1;
    }

    function _checkReentrant() internal {
        require(reentrancyGuard == 1, "Reentrant");
        reentrancyGuard = 2;
    }

    constructor(address _registry, uint256 _delay) {
        REGISTRY = _registry;
        reentrancyGuard = 1;
        __init_Ownable(msg.sender, _delay);
    }

    // ETH进入后会转为WETH
    function deposit(
        address _vault,
        address _asset,
        uint256 _amount,
        uint256 _minSharesOut
    ) external payable nonReentrant {
        if (_asset == ETH) {
            require(msg.value == _amount, "VaultComptroller: msg.value not equal amount");
            IWETH(WETH).deposit{value: _amount}();
            _asset = WETH;
        }
        uint8 decimals = _validateDeposit(_vault, _amount); // 校验vault注册，状态，最小存款金额
        // 先转账, 再更新状态
        if (_asset == WETH && msg.value > 0) {
            // WETH已经在合约内了
            IERC20(WETH).safeTransfer(_vault, _amount);
        } else {
            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        }
        IERC20(_asset).safeTransferFrom(msg.sender, _vault, _amount);
        uint256 sharesOut = _preDepositSetUp(_vault, _asset, _amount, _minSharesOut, decimals);
        IVault(_vault).mint(msg.sender, sharesOut);
        emit Deposit(msg.sender, _vault, _asset, _amount, sharesOut);
    }

    // 计算扣费， 更新vault状态，ETH转WETH等预处理
    function _preDepositSetUp(
        address _vault,
        address _asset,
        uint256 _amount,
        uint256 _minSharesOut,
        uint8 decimals
    ) internal returns (uint256) {
        VaultDataTypes.VaultConfig memory config = IVault(_vault).getVaultConfig();
        // 计算fee
        uint16 depositFeeRate = config.word.getDepositFeeBPS();
        uint256 feeAmount = _amount.mulDiv(depositFeeRate, BPS_DENOMINATOR, Math.Rounding.Ceil); // Fee要上取整
        //防拆单截断逃费或利用拆单套利,虽然有Math.Rounding.Floor, 但是双重保险。DepositFeeRate为0不收费时允许执行
        require(
            feeAmount != 0 || depositFeeRate == 0,
            "VaultComptroller: deposit amount too small for fee"
        );
        // 更新vault Debt状态
        IVault(_vault).updateAccuredFee(feeAmount); //这个函数包含了protocol fee，同时会结算management fee
        uint256 amountAfterFee = _amount - feeAmount;

        // Comptroller不关注nav的计算， 所有与vault交互得到vault资产状态和计算操作都交给ValueInterpreter
        address valueInterpreter = IRegistry(REGISTRY).getValueInterpreter();
        uint256 nav = IValueInterpreter(valueInterpreter).getVaultNAV(_vault); //所有Nav都基于18位精度计算

        // 计算sharesOut， sharesOut = (amountAfterFee / nav) * totalShares
        uint256 totalShares = IVault(_vault).totalSupply(); // 所有Shares都是18位精度
        uint256 sharesOut = amountAfterFee.toWad(decimals).mulDiv(
            totalShares,
            nav,
            Math.Rounding.Floor
        ); // sharesOut向下取整，防止多发shares被套利, 精度为18位
        require(sharesOut >= _minSharesOut, "VaultComptroller: sharesOut less than minSharesOut");

        // 记录Deposit时间戳
        IVault(_vault).setUserDepositTimestamp(msg.sender, block.timestamp);

        return sharesOut;
    }

    function _validateDeposit(
        address _vault,
        address _asset,
        uint256 _amount
    ) internal view returns (uint8) {
        // 校验vault是否注册
        require(
            IRegistry(REGISTRY).isVaultRegistered(_vault),
            "VaultComptroller: vault not registered"
        );
        VaultDataTypes.VaultRiskConfig memory riskConfig = IVault(_vault).getVaultRiskConfig();
        // 校验flags
        (bool isActive, bool isPaused, ) = riskConfig.word.getFlags();

        require(isActive && !isPaused, "VaultComptroller: vault not active or paused");

        // 校验最小存款金额, 后续防拆单逃费，防小额DDOS
        uint96 minDepositAmountE18 = riskConfig.word.getMinDepositAmountE18();
        uint8 assetDecimals = IERC20Metadata(_asset).decimals();
        require(
            _amount.toWad(assetDecimals) >= uint256(minDepositAmountE18),
            "VaultComptroller: amount less than min deposit"
        );

        // 校验存款资产
        address denominationAsset = IVault(_vault).getDenominationAsset();
        require(_asset == denominationAsset, "VaultComptroller: invalid deposit asset");
        return assetDecimals;
    }

    function redeemInKind(
        address _vault,
        address _recipient,
        uint256 _sharesAmount
    ) external nonReentrant returns (address[] memory payoutAssets, address[] memory payoutAmount) {
        _validateRedeem(_vault);

        uint256 sharesAmountAfterFee = _preRedeemSetUp(_vault, _sharesAmount);

        uint256 totalSupply_snapshot = IVault(_vault).totalSupply();
        IVault(_vault).burn(msg.sender, _sharesAmount);

        address[] memory payoutAssets = IVault(_vault).trackedAssets();
        uint256 len = payoutAssets.length;
        address[] memory payoutAmount = new address[](len);

        for (uint256 i = 0; i < len; ) {
            address asset = payoutAssets[i];
            uint256 balance = IERC20(asset).balanceOf(_vault);
            if (balance == 0) {
                payoutAmount.push(0);
                continue;
            }
            // amount需要floor
            uint256 amount = balance.mulDiv(
                sharesAmountAfterFee,
                totalSupply_snapshot,
                Math.Rounding.Floor
            );
            payoutAmount.push(amount);
            IVault(_vault).withdrawTo(_recipient, asset, amount);
            unchecked {
                i++; // payoutLen必然是不会溢出
            }
        }
        emit RedeemInKind(
            _vault,
            msg.sender,
            _recipient,
            _sharesAmount,
            payoutAssets,
            payoutAmount
        );
        return (payoutAssets, payoutAmount);
    }

    function _preRedeemSetUp(address _vault, uint256 _sharesAmount) internal returns (uint256) {
        VaultDataTypes.VaultConfig memory config = IVault(_vault).getVaultConfig();
        uint16 withdrawFeeRate = config.word.getWithdrawFeeBPS();
        // fee需要ceil
        uint256 withdrawFee = _sharesAmount.mulDiv(
            withdrawFeeRate,
            BPS_DENOMINATOR,
            Math.Rounding.Ceil
        );
        IVault(_vault).updateAccuredFee(withdrawFee);
        require(_sharesAmount > withdrawFee, "VaultComptroller: redeem amount too small for fee");
        _sharesAmount -= withdrawFee;
        return _sharesAmount;
    }

    function _validateRedeem(address _vault, uint256 _sharesAmount) internal view {
        // 校验vault是否注册
        require(
            IRegistry(REGISTRY).isVaultRegistered(_vault),
            "VaultComptroller: vault not registered"
        );
        VaultDataTypes.VaultRiskConfig memory riskConfig = IVault(_vault).getVaultRiskConfig();
        // 校验flags
        (bool isActive, bool isPaused, ) = riskConfig.word.getFlags();

        require(isActive && !isPaused, "VaultComptroller: vault not active or paused");

        // 校验Shares余额
        require(
            IERC20(_vault).balanceOf(msg.sender) >= _sharesAmount,
            "VaultComptroller: insufficient shares"
        );

        // 校验赎回冷却时间
        uint32 redeemCooldownTime = riskConfig.word.getRedeemCooldownTime();
        uint256 userLastDepositTime = IVault(_vault).getUserDepositTimestamp(msg.sender);
        // 防止预言机更新时间差套利
        // CoolDown始终大于等于至少两个预言机更新周期，此时无法通过预言机延迟预测Share价格跳变套利
        // 假设有Deposit与Redeem操作有精度套利空间
        // 通过CoolDown禁止同块Deposit与Redeem原子化操作限制闪电贷套利，降低损失提高攻击成本
        // 对正常用户无影响，正常用户不会用闪电贷存钱去策略聚合器中赎回再立刻取出,同时CoolDown为可接受的时间范围
        // 同时防小额DDOS
        require(
            block.timestamp >= userLastDepositTime + uint256(redeemCooldownTime),
            "VaultComptroller: redeem in cooldown period"
        );
    }
}
