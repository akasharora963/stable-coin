// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {StableCoin} from "src/StableCoin.sol";
import {SCEngine} from "src/SCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    StableCoin sc;
    SCEngine scEngine;

    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator wethUsdPriceFeed;
    MockV3Aggregator wbtcUsdPriceFeed;

    uint256 public constant MAX_DEPOSIT = type(uint96).max;

    constructor(StableCoin _sc, SCEngine _scEngine) {
        sc = _sc;
        scEngine = _scEngine;
        address[] memory collateralTokens = scEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        address _wethUsdPriceFeed = scEngine.getCollateralTokenPriceFeed(collateralTokens[0]);

        address _wethBtcPriceFeed = scEngine.getCollateralTokenPriceFeed(collateralTokens[1]);

        wethUsdPriceFeed = MockV3Aggregator(_wethUsdPriceFeed);
        wbtcUsdPriceFeed = MockV3Aggregator(_wethBtcPriceFeed);
    }

    function mintDsc(uint256 amount) public {
        (uint256 totalScMinted, uint256 collateralValueInUsd) = scEngine.getAccountInformation(msg.sender);
        int256 maxScMinted = (int256(collateralValueInUsd) / 2) - int256(totalScMinted);

        if (maxScMinted < 0) {
            return;
        }

        amount = bound(amount, 0, uint256(maxScMinted));

        if (amount == 0) {
            return;
        }

        vm.startPrank(msg.sender);
        scEngine.mintDsc(amount);
        vm.stopPrank();
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateral) public {
        ERC20Mock token = _getCollateral(collateralSeed);
        collateral = bound(collateral, 1, MAX_DEPOSIT);
        vm.startPrank(msg.sender);
        token.mint(msg.sender, collateral);
        token.approve(address(scEngine), collateral);
        scEngine.depositCollateral(address(token), collateral);
        vm.stopPrank();
    }

    // @bug[FAIL: panic: arithmetic underflow or overflow (0x11)]
    function redeemCollateral(uint256 collateralSeed, uint256 collateral) public {
        ERC20Mock token = _getCollateral(collateralSeed);
        uint256 maxRedeemPossible = scEngine.getCollateralBalanceOfUser(address(token), msg.sender);
        collateral = bound(collateral, 0, maxRedeemPossible);
        if (collateral == 0) {
            return;
        }
        scEngine.redeemCollateral(address(token), collateral);
    }

    // function updateCollateralPrice(
    //     uint128 newPrice,
    //     uint256 collateralSeed
    // ) public {
    //     int256 intNewPrice = int256(uint256(newPrice));
    //     //int256 intNewPrice = 0;
    //     if (intNewPrice == 0) {
    //         return;
    //     }
    //     ERC20Mock collateral = _getCollateral(collateralSeed);
    //     MockV3Aggregator priceFeed = MockV3Aggregator(
    //         scEngine.getCollateralTokenPriceFeed(address(collateral))
    //     );

    //     priceFeed.updateAnswer(intNewPrice);
    // }

    function _getCollateral(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
