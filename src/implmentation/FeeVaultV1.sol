// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import { Initializable } from "../abstract/Initializable.sol";

contract FeeVaultV1 is Ownable, Initializable {

    address constant TokenAddr = address(0); 

    receive() external payable virtual {
    }

    function initialize() external initializer {
        _transferOwnership(_msgSender());
    }

    // function makeAndBurnLp() external onlyOwner() {
    //     _sellSFTwithDEX();
    // }

    // function ownerCall() external onlyOwner() {

    // }

    
    // function _sellSFTwithDEX() internal {

    // }

    // function _burnLpToken() internal {
        
    // }

    function withdrawToken(uint256 amount) external onlyOwner() {
        require(ERC20Burnable(TokenAddr).balanceOf(address(this)) >= amount, "Not enough Balance");
        ERC20Burnable(TokenAddr).transfer(_msgSender(), amount);
    }

}