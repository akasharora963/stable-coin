// SPDX-License-Identifier:MIT
pragma solidity ^0.8.13;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 *@title StableCoin
 *@author Akash Arora
 *Collateral: Exogenous(wETH and wBTC)
 *Minting: Algorthmic
 *Relative Stability: Pegged to USD
 *
 *This contract is governed by Coin Engine.It is the implementaion of ERC-20 standard for stable coin system
 */
contract StableCoin is ERC20Burnable, Ownable {
    error StableCoin__ZeroAddress();
    error StableCoin__ZeroAmount();
    error StableCoin__MustNotExceedBalance();

    constructor() ERC20("StableCoin", "SC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableCoin__ZeroAmount();
        }
        if (_amount > balance) {
            revert StableCoin__MustNotExceedBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        if (_to == address(0)) {
            revert StableCoin__ZeroAddress();
        }
        if (_amount <= 0) {
            revert();
        }
        _mint(_to, _amount);
    }
}
