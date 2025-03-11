// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

interface ISCEngine {
    /*//////////////////////////////////////////////////////////////
                        ERRORS
    //////////////////////////////////////////////////////////////*/
    error SCEngine__ZeroAmount();
    error SCEngine__InvalidLength();
    error SCEngine__NotAllowedToken();
    /*//////////////////////////////////////////////////////////////
                           FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositCollateralAndMintDsc() external;

    /**
     * @dev Deposits `amount` of `token` to the contract
     * @param token The address of the token to deposit
     * @param amount The amount of the token to deposit
     */
    function depositCollateral(address token, uint256 amount) external;

    function redeemCollateralForDsc() external;

    function redeemCollateral() external;

    function mintDsc() external;

    function burnDsc() external;

    function liquidate() external;

    function getHealthFactor() external view returns (uint256);
}
