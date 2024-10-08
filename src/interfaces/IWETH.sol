// SPDX-License-Identifier: MIT

// File: contracts/IWETH.sol

pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}