// SPDX-License-Identifier:MIT
pragma solidity ^0.8.26;

interface ISCEngine {
    function depositCollateralAndMintDsc() external;

    function depositCollateral() external;

    function redeemCollateralForDsc() external;

    function redeemCollateral() external;

    function mintDsc() external;

    function burnDsc() external;

    function liquidate() external;

    function getHealthFactor() external view returns (uint256);
}
