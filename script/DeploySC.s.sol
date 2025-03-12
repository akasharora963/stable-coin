// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {StableCoin} from "src/StableCoin.sol";
import {SCEngine} from "src/SCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableCoin, SCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            address deployer
        ) = helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployer);
        StableCoin sc = new StableCoin();
        SCEngine scEngine = new SCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(sc)
        );
        sc.transferOwnership(address(scEngine));
        vm.stopBroadcast();
        return (sc, scEngine, helperConfig);
    }
}
