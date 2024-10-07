//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface ISafeswapCallee {
    function safeswapCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
