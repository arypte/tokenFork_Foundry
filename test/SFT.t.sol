// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import {Test, console} from "forge-std/Test.sol";
import {Safemoon} from "../src/implmentation/Safemoon.sol";
import {SafeswapFactory, SafeswapPair} from "../src/implmentation/SafeswapFactory.sol";
import {SafeswapRouterProxy1} from "../src/implmentation/SafeswapRouterProxy1.sol";
import {SafeswapRouterProxy2} from "../src/implmentation/SafeswapRouterProxy2.sol";
import {FeeJar} from "../src/implmentation/FeeJar.sol";
import {SafeSwapTradeRouter} from "../src/implmentation/SafeSwapTradeRouter.sol";
import {ISafeswapERC20} from "../src/interfaces/ISafeswapERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {TestSetup} from "./TestSetup.t.sol";

contract SFT is TestSetup {
    function setUp() public {
        _testSetup();
    }

    function test_Mint() public {
        /* 
            1. owner 계정에서 민팅
            2. 100 ETH, 100 SFT 공급
            3. 100 SFT 판매
         */



        // ISafeswapERC20 v2pair = ISafeswapERC20(safeswapFactory.getPair(address(safeMoon), WETH));

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

        /* AccountB 판매 */
        vm.startPrank(accountB);
        safeMoon.approve(address(safeswapRouterProxy1), 1000 * SFT_DECIMAL);
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 1 ether}(tradeParam);
        vm.stopPrank();
    }
}
