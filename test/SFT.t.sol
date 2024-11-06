// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { TestSetup } from "./TestSetup.t.sol";

contract SFT is TestSetup {
    function setUp() public {
        _testSetup();
    }

    //! testfail , test_fail 차이
    function test_failaddLq() public {
    
        vm.startPrank(accountA);
        vm.expectRevert("TransferHelper::transferFrom: transferFrom failed");
        safeMoon.approve(address(safeswapRouterProxy1), 5000 * SFT_DECIMAL);

        safeswapRouterProxy1.addLiquidityETH{value: 5 ether}(
            address(safeMoon),      // token
            50000 * SFT_DECIMAL,    // amountTokenDesired
            0,                      // amountTokenMin
            0,                      // amountETHMin
            accountA,               // to
            0                       // deadline
        );

        vm.stopPrank();
    }

    function test_addLqSwap() public {
        /* 
            1. AccountA: (5000 SFT, 5 ETH) LP 공급
            2. AccountB: 1000 SFT를 판매
        */
        vm.startPrank(accountA);
        safeMoon.approve(address(safeswapRouterProxy1), 5000 * SFT_DECIMAL);
        safeswapRouterProxy1.addLiquidityETH{value: 5 ether}(
            address(safeMoon),      // token
            5000 * SFT_DECIMAL,     // amountTokenDesired
            0,                      // amountTokenMin
            0,                      // amountETHMin
            accountA,               // to
            0                       // deadline
        );
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(safeMoon);
        path[1] = WETH;
        SafeSwapTradeRouter.Trade memory tradeParam = SafeSwapTradeRouter.Trade({
            amountIn: 1000 * 10 ** 9,
            amountOut: 1 * 10 ** 17,
            path: path,
            to: payable(accountB),
            deadline: block.timestamp + 1000
        });

        uint256 accountCBalanceBefore = safeMoon.balanceOf(accountC);

        /* AccountB 판매 */
        vm.startPrank(accountB);
        safeMoon.approve(address(safeswapRouterProxy1), 1000 * SFT_DECIMAL);
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 1 ether}(tradeParam);
        vm.stopPrank();

        uint256 accountCBalanceAfter = safeMoon.balanceOf(accountC);
        assertTrue(accountCBalanceAfter > accountCBalanceBefore, "Balance Increase Failed");
    }

}