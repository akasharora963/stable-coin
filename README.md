# Stable Coin Engine

A decentralized stablecoin system utilizing exogenous collateral and algorithmic minting mechanisms to maintain a peg to the US Dollar.

## Overview

This project implements a stablecoin system that combines external collateral assets with algorithmic strategies to ensure price stability relative to the USD. The system leverages wrapped Ethereum (wETH) and wrapped Bitcoin (wBTC) as collateral, providing a robust foundation for the stablecoin's value.

## Features

- **Exogenous Collateral**: Utilizes wETH and wBTC as collateral assets, ensuring the stablecoin's value is backed by established cryptocurrencies.
- **Algorithmic Minting**: Employs algorithmic mechanisms to manage the supply of the stablecoin
-  **Relative Stability**: Pegged to USD via chainlink pricefeed


## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) – A blazing fast, portable, and modular toolkit for Ethereum application development written in Rust.

### Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/akasharora963/stable-coin.git
   cd stable-coin
   ```

2. **Install Dependencies**:

   ```bash
   forge install smartconractkit/chainlink --no-commit
   forge install openzeppelin/openzeppelin-contracts --no-commit
   ```

3. **Build the Project**:

   ```bash
   forge build
   ```
4. **Deploy Scripts**

    ```bash
    forge script script/DeploySC.s.sol:DeploySC 
    ```
5. **Run Tests**:

   ```bash
   forge test
   ```

## Usage

This project serves as a foundational framework for developing a stablecoin system. Developers can extend and customize the provided smart contracts to suit specific requirements. Key components include:

- **Collateral Management**: Handling deposits and withdrawals of wETH and wBTC.
- **Stablecoin Minting and Burning**: Functions to mint new stablecoins against collateral and burn them during redemption.
- **Price Oracle Integration**: Incorporating reliable price feeds to monitor collateral values and ensure proper collateralization ratios.

## SCEngine Contarct Methods
| Method                                               | Identifier |
|------------------------------------------------------|------------|
| `burnDsc(uint256)`                                   | `f6876608`  |
| `calculateHealthFactor(uint256,uint256)`            | `01f72884`  |
| `depositCollateral(address,uint256)`                | `a5d5db0c`  |
| `depositCollateralAndMintDsc(address,uint256,uint256)` | `e90db8a3`  |
| `getAccountCollateralValueInUsd(address)`           | `545af4fe`  |
| `getAccountInformation(address)`                    | `7be564fc`  |
| `getCollateralBalanceOfUser(address,address)`       | `31e92b83`  |
| `getCollateralTokenPriceFeed(address)`              | `1c08adda`  |
| `getCollateralTokens()`                             | `b58eb63f`  |
| `getHealthFactor(address)`                          | `fe6bcd7c`  |
| `getLiquidationBonus()`                             | `59aa9e72`  |
| `getLiquidationPrecision()`                         | `6c8102c0`  |
| `getLiquidationThreshold()`                         | `4ae9b8bc`  |
| `getMinHealthFactor()`                              | `8c1ae6c8`  |
| `getPrecision()`                                    | `9670c0bc`  |
| `getPriceFeedPrecision()`                           | `a2e1bacc`  |
| `getPriceInUsd(address,uint256)`                    | `d0578a01`  |
| `getStableCoin()`                                   | `1bd817c9`  |
| `getTokenAmountFromUsd(address,uint256)`           | `afea2e48`  |
| `liquidate(address,address,uint256)`               | `26c01303`  |
| `mintDsc(uint256)`                                  | `c9b7c327`  |
| `redeemCollateral(address,uint256)`                | `9acd81b3`  |
| `redeemCollateralForDsc(address,uint256,uint256)`  | `f419ea9c`  |


## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -m 'Add YourFeature'`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a Pull Request.

## Acknowledgments

- Inspired by various decentralized finance (DeFi) projects specially MakerDAO.
---

*Note: This project is for educational purposes and should not be used in production without proper security audits and testing.*


