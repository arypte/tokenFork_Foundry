// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract FeeVault is Ownable{

    function makeAndBurnLp() external onlyOwner(){

        _sellSFTwithDEX();
    }

    function ownerCall() external onlyOwner(){

    }

    
    function _sellSFTwithDEX() internal {

    }

    function _burnLpToken() internal {
        
    }

}