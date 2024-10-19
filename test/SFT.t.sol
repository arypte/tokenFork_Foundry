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

        // owner 계정에서 민팅
        vm.startPrank(owner); // owner로 행동을 시뮬레이션
        safeMoon.mint(accountA, 10000 * SFT_DECIMAL); // A 계정에 10000 토큰 민팅
        safeMoon.mint(accountB, 20000 * SFT_DECIMAL); // B 계정에 20000 토큰 민팅
        safeMoon.mint(accountC, 30000 * SFT_DECIMAL); // B 계정에 30000 토큰 민팅
        vm.stopPrank();

        // ISafeswapERC20 v2pair = ISafeswapERC20(safeswapFactory.getPair(address(safeMoon), WETH));

        vm.prank(accountA);
        safeMoon.approve(address(safeswapRouterProxy1), 5000 * SFT_DECIMAL);
        safeswapRouterProxy1.addLiquidityETH{value: 5 ether}(address(safeMoon), 5000 * SFT_DECIMAL, 0, 0, accountA, 0);
        vm.stopPrank();

        // ISafeswapERC20 weth = ISafeswapERC20(WETH);
        // console.log("before Swap");
        // console.log("owner sft balance : ", safeMoon.balanceOf(owner));
        // console.log("owner weth balance : ", weth.balanceOf(owner));
        // console.log("owner balance : ", owner.balance);
        // console.log("pair sft bal : ", safeMoon.balanceOf(address(v2pair)));
        // console.log("pair weth bal : ", weth.balanceOf(address(v2pair)));
        // console.log("Bbal : ", safeMoon.balanceOf(accountB));
        // console.log("Cbal : ", safeMoon.balanceOf(accountC));

        address[] memory path = new address[](2);
        path[0] = address(safeMoon);
        path[1] = WETH;
        SafeSwapTradeRouter.Trade memory tradeParam = SafeSwapTradeRouter.Trade({
            amountIn: 1000 * SFT_DECIMAL,
            amountOut: 0.1 ether,
            path: path,
            to: payable(accountB),
            deadline: block.timestamp + 1000
        });

        /* AccountB 판매 */
        vm.startPrank(accountB);
        safeMoon.approve(address(safeswapRouterProxy1), 2000 * SFT_DECIMAL);
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 1 ether}(tradeParam);
        vm.stopPrank();

        // console.log("after Swap");
        // console.log("owner sft balance : ", safeMoon.balanceOf(owner));
        // console.log("owner weth balance : ", weth.balanceOf(owner));
        // console.log("owner balance : ", owner.balance);
        // console.log("pair sft bal : ", safeMoon.balanceOf(address(v2pair)));
        // console.log("pair weth bal : ", weth.balanceOf(address(v2pair)));
        // console.log("Bbal : ", safeMoon.balanceOf(accountB));
        // console.log("Cbal : ", safeMoon.balanceOf(accountC));
    }
}
