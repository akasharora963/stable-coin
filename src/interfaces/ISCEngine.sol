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

    function liquidate() external;

    function getHealthFactor() external view returns (uint256);
}
