// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {StableCoin} from "src/StableCoin.sol";
import {SCEngine} from "src/SCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    StableCoin sc;
    SCEngine scEngine;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public constant MAX_DEPOSIT = type(uint96).max;

    constructor(StableCoin _sc, SCEngine _scEngine) {
        sc = _sc;
        scEngine = _scEngine;
        address[] memory collateralTokens = scEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
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

    function _getCollateral(uint256 seed) private view returns (ERC20Mock) {
        if (seed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
