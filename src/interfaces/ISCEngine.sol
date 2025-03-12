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

    function redeemCollateralForDsc() external;

    function redeemCollateral() external;

    function burnDsc() external;

    function liquidate() external;

    function getHealthFactor() external view returns (uint256);
}
