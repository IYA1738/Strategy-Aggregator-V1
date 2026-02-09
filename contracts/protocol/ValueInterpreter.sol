//SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "contracts/protocol/Interfaces/IValueInterpreter.sol";
import "contracts/protocol/Interfaces/IVault.sol";
import "contracts/protocol/Interfaces/IRegistry.sol";
import "contracts/protocol/Interfaces/IOracleAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/protocol/Utils/WadMath.sol";

/// @dev Basic NAV calculator. Sums tracked assets priced in USD using OracleAggregator,
///      then converts to denomination-asset terms. Replace with full accounting as strategies integrate.
contract ValueInterpreter is IValueInterpreter {
    using WadMath for uint256;
    using Math for uint256;

    address public immutable registry;

    constructor(address _registry) {
        registry = _registry;
    }

    function getVaultNAV(address _vault) external view override returns (uint256 navE18) {
        IVault vault = IVault(_vault);
        address denom = vault.getDenominationAsset();

        address oracleAgg = IRegistry(registry).getOracleAggregator();
        uint256 denomPrice = IOracleAggregator(oracleAgg).getPriceInUSD(denom);
        require(denomPrice > 0, "ValueInterpreter: denom price unavailable");

        address[] memory assets = vault.trackedAssets();
        uint256 len = assets.length;

        for (uint256 i = 0; i < len; ) {
            address asset = assets[i];
            uint256 balance = IERC20(asset).balanceOf(_vault);
            if (balance > 0) {
                uint8 dec = IERC20Metadata(asset).decimals();
                if (asset == denom) {
                    navE18 += balance.toWad(dec);
                } else {
                    uint256 price = IOracleAggregator(oracleAgg).getPriceInUSD(asset);
                    require(price > 0, "ValueInterpreter: price unavailable");
                    // value in denom = balance * price_asset / price_denom
                    uint256 valueInDenom = Math.mulDiv(balance.toWad(dec), price, denomPrice);
                    navE18 += valueInDenom;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
