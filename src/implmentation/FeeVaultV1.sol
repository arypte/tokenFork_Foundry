// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import { Initializable } from "../abstract/Initializable.sol";

contract FeeVaultV1 is Ownable, Initializable {

    address tokenAddr;

    receive() external payable virtual {
    }

    function initialize(address _addr) external initializer {
        _transferOwnership(_msgSender());
        tokenAddr = _addr;
    }

    function withdrawToken(uint256 amount) external onlyOwner() {
        require(ERC20Burnable(tokenAddr).balanceOf(address(this)) >= amount, "Not enough Balance");
        ERC20Burnable(tokenAddr).transfer(_msgSender(), amount);
    }

    function withdrawNative(uint256 amount) external onlyOwner() {
        require(address(this).balance >= amount, "Not enough Balance");
        payable(_msgSender()).transfer(amount); 
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

}