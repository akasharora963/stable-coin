// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeploySC} from "script/DeploySC.s.sol";
import {StableCoin} from "src/StableCoin.sol";
import {SCEngine} from "src/SCEngine.sol";
import {ISCEngine} from "src/interfaces/ISCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract SCEngineTest is Test {
    DeploySC deployer;
    StableCoin sc;
    SCEngine scEngine;
    HelperConfig helperConfig;

    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    address public USER = makeAddr("user");

    uint256 public constant START_BALANCE = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    address[] public tokens;
    address[] public priceFeeds;

    function setUp() external {
        deployer = new DeploySC();
        (sc, scEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
        ERC20Mock(weth).mint(USER, START_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                         CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevertsIfTokenLengthMismatchPriceFeeds() public {
        tokens.push(weth);
        priceFeeds.push(wbtcUsdPriceFeed);
        priceFeeds.push(wethUsdPriceFeed);
        vm.expectRevert(ISCEngine.SCEngine__InvalidLength.selector);
        new SCEngine(tokens, priceFeeds, address(sc));
    }

    /*//////////////////////////////////////////////////////////////
                           PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetPriceInUsd() public view {
        uint256 wethAmount = 15e18;
        uint256 expectedWethPrice = 30000e18; //15e18 * 2000/ETH
        uint256 actualWethPrice = scEngine.getPriceInUsd(weth, wethAmount);
        assertEq(expectedWethPrice, actualWethPrice);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 wethAmount = 100 ether;
        uint256 expectedWethPrice = 0.05 ether; //100 ether / 2000$
        uint256 actualWethPrice = scEngine.getTokenAmountFromUsd(
            weth,
            wethAmount
        );
        assertEq(expectedWethPrice, actualWethPrice);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT COLLATERAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevertIfCollateralZero() public {
        uint256 wethAmount = 0;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(USER, AMOUNT_COLLATERAL);
        vm.expectRevert(ISCEngine.SCEngine__ZeroAmount.selector);
        scEngine.depositCollateral(weth, wethAmount);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(ISCEngine.SCEngine__NotAllowedToken.selector);
        scEngine.depositCollateral(address(randToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
}
