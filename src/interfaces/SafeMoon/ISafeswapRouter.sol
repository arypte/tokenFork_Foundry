// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ISafeswapRouter {
    function getTokenDeduction(address token, uint256 amount) external view returns (uint256, address);
}
