// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeploySC} from "script/DeploySC.s.sol";
import {StableCoin} from "src/StableCoin.sol";
import {SCEngine} from "src/SCEngine.sol";
import {ISCEngine} from "src/interfaces/ISCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Invarianta aka properties that the system must maintain

// 1. Health factor > MIN_HEALTH_FACTOR
// 2. Totalsupply of stable coin should be less than total value of collateral
// 3. Getter view functions should never revert
contract OpenInvariantTest is StdInvariant, Test {
    DeploySC deployer;
    StableCoin sc;
    SCEngine scEngine;
    HelperConfig helperConfig;

    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeploySC();
        (sc, scEngine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
        targetContract(address(scEngine));
    }

    function invariant_OpenTest_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = sc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(scEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(scEngine));
        uint256 wethUsd = scEngine.getPriceInUsd(weth, totalWethDeposited);
        uint256 wbtcUsd = scEngine.getPriceInUsd(wbtc, totalWbtcDeposited);
        uint256 totalValueDeposited = wethUsd + wbtcUsd;
        assert(totalSupply <= totalValueDeposited);
    }
}
