// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

interface ISCEngine {
    /*//////////////////////////////////////////////////////////////
                        ERRORS
    //////////////////////////////////////////////////////////////*/
    error SCEngine__ZeroAmount();
    error SCEngine__InvalidLength();
    error SCEngine__NotAllowedToken();
    error SCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error SCEngine__MintFailed();
    error SCEngine__HealthFactorOk();
    error SCEngine__HealthFactorNotImproved();
    /*//////////////////////////////////////////////////////////////
                           FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Deposits `amount` of `token` to the contract and mint stable coin in one transaction
     * @param token The address of the token to deposit
     * @param collateral The amount of the token to deposit as collateral
     * @param mintAmount  The amount of tokens to mint
     */
    function depositCollateralAndMintDsc(address token, uint256 collateral, uint256 mintAmount) external;

    /**
     * @dev Deposits `amount` of `token` to the contract
     * @param token The address of the token to deposit
     * @param collateral The amount of the token to deposit
     */
    function depositCollateral(address token, uint256 collateral) external;

    /**
     * @dev Mints `amount` of stable coin
     * @param amountToMint The amount of stable coin to mint
     */
    function mintDsc(uint256 amountToMint) external;

    /**
     * @dev Redeems `amount` of `token` from the contract and burn stable coin in one transaction
     * @param token The address of the token to redeem
     * @param collateral The amount of the token that deposited as collateral
     * @param burnAmount  The amount of tokens to burn
     */
    function redeemCollateralForDsc(address token, uint256 collateral, uint256 burnAmount) external;

    /**
     * @dev redeem the amount of collateral token by giving the stable coin back
     * @param token The address of the token to redeem
     * @param collateral The amount of the token that deposited as collateral
     */
    function redeemCollateral(address token, uint256 collateral) external;

    /**
     * @dev Burns `amount` of stable coin
     * @param amountToBurn The amount of stable coin to burn
     */
    function burnDsc(uint256 amountToBurn) external;

    /**
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your DSC to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of DSC you want to burn to cover the user's debt.
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external;
    /*//////////////////////////////////////////////////////////////
                         EXTERNAL VIEw FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function calculateHealthFactor(uint256 totalScMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256);

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd);

    function getPrecision() external pure returns (uint256);

    function getPriceFeedPrecision() external pure returns (uint256);

    function getLiquidationThreshold() external pure returns (uint256);

    function getLiquidationBonus() external pure returns (uint256);

    function getLiquidationPrecision() external pure returns (uint256);

    function getMinHealthFactor() external pure returns (uint256);

    function getCollateralTokens() external view returns (address[] memory);

    function getStableCoin() external view returns (address);

    function getCollateralTokenPriceFeed(address token) external view returns (address);

    function getCollateralBalanceOfUser(address token, address user) external view returns (uint256);

    function getHealthFactor(address user) external view returns (uint256);
}
