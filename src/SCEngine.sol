// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {ISCEngine} from "src/interfaces/ISCEngine.sol";
import {StableCoin} from "src/StableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
/*
 * @title SCEngine
 * @author Akash Arora
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the SC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract SCEngine is ISCEngine, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant PRICE_FEED_PRECISION = 1e10;
    uint256 private constant ETH_PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% overcollateralization
    uint256 private constant LIQUIDATION_THRESHOLD_PRECISION = 1e2;
    uint256 private constant MIN_HEALTH_FACTOR = 1; //200% overcollateralization

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    mapping(address user => uint256 scMinted) private s_scMinted;
    StableCoin private immutable i_stableCoin;
    address[] private s_collateralTokens;
    /*//////////////////////////////////////////////////////////////
                           EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    /*//////////////////////////////////////////////////////////////
                           MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) revert SCEngine__ZeroAmount();
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert SCEngine__NotAllowedToken();
        }
        _;
    }
    /*//////////////////////////////////////////////////////////////
                           FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(
        address[] memory tokens,
        address[] memory priceFeeds,
        address stableCoin
    ) {
        if (tokens.length != priceFeeds.length) {
            revert SCEngine__InvalidLength();
        }
        uint256 _length = tokens.length;
        for (uint256 i = 0; i < _length; i++) {
            s_priceFeeds[tokens[i]] = priceFeeds[i];
            s_collateralTokens.push(tokens[i]);
        }
        i_stableCoin = StableCoin(stableCoin);
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Deposits `amount` of `token` to the contract and mint stable coin in one transaction
     * @param token The address of the token to deposit
     * @param collateral The amount of the token to deposit as collateral
     * @param mintAmount  The amount of tokens to mint
     */
    function depositCollateralAndMintDsc(
        address token,
        uint256 collateral,
        uint256 mintAmount
    ) external {
        depositCollateral(token, collateral);
        mintDsc(mintAmount);
    }

    /**
     * @dev Deposits `amount` of `token` to the contract
     * @param token The address of the token to deposit
     * @param amount The amount of the token to deposit
     */
    function depositCollateral(
        address token,
        uint256 amount
    ) public moreThanZero(amount) isAllowedToken(token) nonReentrant {
        s_collateralDeposited[msg.sender][token] += amount;
        emit CollateralDeposited(msg.sender, token, amount);
        _safeTransferFrom(token, msg.sender, address(this), amount);
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    /**
     * @dev Mints `amount` of DSC
     * @param amountToMint The amount of DSC to mint
     * @notice theremust be enough collateral to cover the DSC that is being greater than the thresshold value
     */
    function mintDsc(
        uint256 amountToMint
    ) public moreThanZero(amountToMint) nonReentrant {
        s_scMinted[msg.sender] += amountToMint;
        _revertIfHealthFactorTooLow(msg.sender);
        bool minted = i_stableCoin.mint(msg.sender, amountToMint);
        if (!minted) {
            revert SCEngine__MintFailed();
        }
    }

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view returns (uint256) {}

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                value
            )
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /*//////////////////////////////////////////////////////////////
                         PRIVATE AND INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getUserAccountInfo(
        address user
    )
        internal
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        totalScMinted = s_scMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    function _healthFactor(address user) internal view returns (uint256) {
        (
            uint256 totalScMinted,
            uint256 collateralValueInUsd
        ) = _getUserAccountInfo(user);
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    function _calculateHealthFactor(
        uint256 totalScMinted,
        uint256 collateralValueInUsd
    ) internal pure returns (uint256) {
        if (totalScMinted == 0) return type(uint256).max;
        uint256 collateralThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_THRESHOLD_PRECISION;
        //False Case
        // $150 ETH / 100 SC = 1.5
        // 150*50= 7500/100 = 75, 75/100 < 1

        //True Case
        // $1000 ETH / 100 SC
        // 1000*50= 50000/100 = 500, 500/100 > 1
        return (collateralThreshold * ETH_PRECISION) / totalScMinted;
    }

    function _revertIfHealthFactorTooLow(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         PUBLIC AND EXTERNAL VIEw FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAccountCollateralValueInUsd(
        address user
    ) public view returns (uint256 totalCollateralValue) {
        uint256 _length = s_collateralTokens.length;
        for (uint256 i = 0; i < _length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValue += getPriceInUsd(token, amount);
        }
    }

    function getPriceInUsd(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return (uint256(price) * PRICE_FEED_PRECISION * amount) / ETH_PRECISION;
    }

    function calculateHealthFactor(
        uint256 totalScMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        return _getUserAccountInfo(user);
    }
}
