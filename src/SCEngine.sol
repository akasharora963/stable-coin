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
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 scMinted) private s_scMinted;
    StableCoin private immutable i_stableCoin;
    address[] private s_collateralTokens;
    /*//////////////////////////////////////////////////////////////
                           EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
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

    constructor(address[] memory tokens, address[] memory priceFeeds, address stableCoin) {
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
    function depositCollateralAndMintDsc(address token, uint256 collateral, uint256 mintAmount)
        external
        moreThanZero(collateral)
        moreThanZero(mintAmount)
        isAllowedToken(token)
        nonReentrant
    {
        _depositCollateral(token, collateral);
        _mintDsc(mintAmount);
    }

    /**
     * @dev Deposits `amount` of `token` to the contract
     * @param token The address of the token to deposit
     * @param collateral The amount of the token to deposit
     */
    function depositCollateral(address token, uint256 collateral)
        external
        moreThanZero(collateral)
        isAllowedToken(token)
        nonReentrant
    {
        _depositCollateral(token, collateral);
    }

    /**
     * @dev Mints `amount` of stable coin
     * @param amountToMint The amount of stable coin to mint
     */
    function mintDsc(uint256 amountToMint) external moreThanZero(amountToMint) nonReentrant {
        _mintDsc(amountToMint);
    }

    /**
     * @dev Redeems `amount` of `token` from the contract and burn stable coin in one transaction
     * @param token The address of the token to redeem
     * @param collateral The amount of the token that deposited as collateral
     * @param burnAmount  The amount of tokens to burn
     */
    function redeemCollateralForDsc(address token, uint256 collateral, uint256 burnAmount)
        external
        moreThanZero(collateral)
        nonReentrant
        isAllowedToken(token)
    {
        _burnDsc(burnAmount, msg.sender, msg.sender);
        _redeemCollateral(token, collateral, msg.sender, msg.sender);
        _revertIfHealthFactorTooLow(msg.sender);
    }

    /**
     * @dev redeem the amount of collateral token by giving the stable coin back
     * @param token The address of the token to redeem
     * @param collateral The amount of the token that deposited as collateral
     */
    function redeemCollateral(address token, uint256 collateral)
        external
        moreThanZero(collateral)
        nonReentrant
        isAllowedToken(token)
    {
        _redeemCollateral(token, collateral, msg.sender, msg.sender);
        _revertIfHealthFactorTooLow(msg.sender);
    }

    /**
     * @dev Burns `amount` of stable coin
     * @param amountToBurn The amount of stable coin to burn
     */
    function burnDsc(uint256 amountToBurn) external moreThanZero(amountToBurn) nonReentrant {
        _burnDsc(amountToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorTooLow(msg.sender);
    }

    /**
     * @notice You can partially liquidate a user.
     * @notice You will get a LIQUIDATION_BONUS for taking the user's funds.
     * @notice This function assumes that the protocol will be roughly 200% overcollateralized for proper liquidation.
     * @notice A known issue is if the protocol is only 100% collateralized, liquidation may not be possible.
     * For example, if the price of the collateral plummets before anyone can be liquidated.
     *
     * @param collateral The ERC20 token address of the collateral used to restore protocol solvency.
     * This collateral will be taken from the insolvent user.
     * @param user The insolvent user with a `_healthFactor` below `MIN_HEALTH_FACTOR`.
     * @param debtToCover The amount of DSC to be burned to cover the user's debt.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorOk();
        }
        // If covering 100 DSC, we need to $100 of collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);

        // And give them a 10% bonus
        // So we are giving the liquidator $110 of WETH for 100 DSC
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_THRESHOLD_PRECISION;

        // Burn DSC equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt
        _redeemCollateral(collateral, tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);

        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert SCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorTooLow(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /*//////////////////////////////////////////////////////////////
                          PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Deposits `amount` of `token` to the contract
     * @param token The address of the token to deposit
     * @param amount The amount of the token to deposit
     */
    function _depositCollateral(address token, uint256 amount) private {
        s_collateralDeposited[msg.sender][token] += amount;
        emit CollateralDeposited(msg.sender, token, amount);
        _safeTransferFrom(token, msg.sender, address(this), amount);
    }

    /**
     * @dev Mints `amount` of stable coin
     * @param amountToMint The amount of stable coin  to mint
     * @notice there must be enough collateral to cover the stable coin that is being greater than the thresshold value
     */
    function _mintDsc(uint256 amountToMint) private {
        s_scMinted[msg.sender] += amountToMint;
        _revertIfHealthFactorTooLow(msg.sender);
        bool minted = i_stableCoin.mint(msg.sender, amountToMint);
        if (!minted) {
            revert SCEngine__MintFailed();
        }
    }

    /**
     * @dev redeem the amount of collateral token by giving the stable coin back
     * @param token The address of the token to redeem
     * @param collateral The amount of the token that deposited as collateral
     * @param from The address of the user that redeems the collateral
     * @param to The address of the user that receives the stable coin
     * @notice there must be enough collateral to maintain the health factor > MIN_HEALTH_FACTOR.
     */
    function _redeemCollateral(address token, uint256 collateral, address from, address to) private {
        s_collateralDeposited[from][token] -= collateral;
        emit CollateralRedeemed(from, to, token, collateral);
        _safeTransfer(token, to, collateral);
    }

    /**
     * @dev Burn `amount` of stable coin
     * @param amountToBurn The amount of stable coin to burn
     * @param onBehalfOf The address of the user for whom we are burning the stable coin
     * @param dscFrom The address of the user that provides the stable coin
     * @notice the stable coin transfer from user to contract and then burn mechanism take place
     */
    function _burnDsc(uint256 amountToBurn, address onBehalfOf, address dscFrom) private {
        s_scMinted[onBehalfOf] -= amountToBurn;
        _safeTransferFrom(address(i_stableCoin), dscFrom, address(this), amountToBurn);
        i_stableCoin.burn(amountToBurn);
    }

    /*//////////////////////////////////////////////////////////////
                         PRIVATE AND INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getUserAccountInfo(address user)
        internal
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        totalScMinted = s_scMinted[user];
        collateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalScMinted, uint256 collateralValueInUsd) = _getUserAccountInfo(user);
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    function _calculateHealthFactor(uint256 totalScMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalScMinted == 0) return type(uint256).max;
        uint256 collateralThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_THRESHOLD_PRECISION;
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
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValue) {
        uint256 _length = s_collateralTokens.length;
        for (uint256 i = 0; i < _length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValue += getPriceInUsd(token, amount);
        }
    }

    function getPriceInUsd(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return (uint256(price) * PRICE_FEED_PRECISION * amount) / ETH_PRECISION;
    }

    function calculateHealthFactor(uint256 totalScMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        return _getUserAccountInfo(user);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // The returned value from Chainlink will be 2000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        return ((usdAmountInWei * ETH_PRECISION) / (uint256(price) * PRICE_FEED_PRECISION));
    }

    function getPrecision() external pure returns (uint256) {
        return ETH_PRECISION;
    }

    function getPriceFeedPrecision() external pure returns (uint256) {
        return PRICE_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getStableCoin() external view returns (address) {
        return address(i_stableCoin);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getCollateralBalanceOfUser(address token, address user) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
