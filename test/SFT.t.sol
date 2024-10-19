// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import {Test, console} from "forge-std/Test.sol";
import { Safemoon } from "../src/implmentation/Safemoon.sol";
import { SafeswapFactory, SafeswapPair } from "../src/implmentation/SafeswapFactory.sol";
import { SafeswapRouterProxy1 } from "../src/implmentation/SafeswapRouterProxy1.sol";
import { SafeswapRouterProxy2 } from "../src/implmentation/SafeswapRouterProxy2.sol";
import { FeeJar } from "../src/implmentation/FeeJar.sol";
import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { ISafeswapERC20 } from "../src/interfaces/ISafeswapERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { TestSetup } from "./TestSetup.t.sol";

contract SFT is TestSetup {
    function setUp() public {
        _testSetup();
    }

    function test_Mint() public {
        // owner 계정에서 민팅
        vm.startPrank(owner); // owner로 행동을 시뮬레이션
        safeMoon.mint(accountA, 100 * 10 ** 9); // A 계정에 1000 토큰 민팅
        safeMoon.mint(accountB, 200 * 10 ** 9); // B 계정에 2000 토큰 민팅
        safeMoon.mint(accountC, 300 * 10 ** 9); // B 계정에 2000 토큰 민팅
        vm.stopPrank();

        ISafeswapERC20 v2pair = ISafeswapERC20(safeswapFactory.getPair(address(safeMoon),WETH));
        
        vm.prank(accountA);        
        safeMoon.approve(address(safeswapRouterProxy1), 100 * 10 ** 9);

        vm.prank(accountA);        
        safeswapRouterProxy1.addLiquidityETH{value: 100 ether}(address(safeMoon), 100 * 10 ** 9,0,0,accountA,0);
        
        ISafeswapERC20 weth = ISafeswapERC20(WETH);
        console.log("before Swap");
        console.log("owner sft balance : " , safeMoon.balanceOf(owner));
        console.log("owner weth balance : " , weth.balanceOf(owner));
        console.log("owner balance : " ,owner.balance);
        console.log("pair sft bal : " , safeMoon.balanceOf(address(v2pair)));
        console.log("pair weth bal : " , weth.balanceOf(address(v2pair)));
        console.log("Bbal : " , safeMoon.balanceOf(accountB));
        console.log("Cbal : " , safeMoon.balanceOf(accountC));

        SafeSwapTradeRouter.Trade memory temp;
        temp.amountIn = 50 * 10 ** 9;
        temp.amountOut = 1 * 10 ** 18;
        
        address[] memory temp2 = new address[](2);
        temp2[0] = address(safeMoon);
        temp2[1] = WETH;
        temp.path = temp2;

        temp.to = payable(accountB);
        temp.deadline = block.timestamp + 1000 ;

        vm.startPrank(accountB);
        safeMoon.approve(address(safeSwapTradeRouter), 100 * 10 ** 9);
        safeMoon.approve(address(safeswapRouterProxy1), 100 * 10 ** 9);
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{ value : 3573901284651791751 }(temp);
        vm.stopPrank();
        
        console.log("after Swap");
        console.log("owner sft balance : " , safeMoon.balanceOf(owner));
        console.log("owner weth balance : " , weth.balanceOf(owner));
        console.log("owner balance : " ,owner.balance);
        console.log("pair sft bal : " , safeMoon.balanceOf(address(v2pair)));
        console.log("pair weth bal : " , weth.balanceOf(address(v2pair)));
        console.log("Bbal : " , safeMoon.balanceOf(accountB));
        console.log("Cbal : " , safeMoon.balanceOf(accountC));
    }
}