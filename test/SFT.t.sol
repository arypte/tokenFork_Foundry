// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import {Test, console} from "forge-std/Test.sol";
import { Safemoon } from "../src/implmentation/Safemoon.sol";
import { SafeswapFactory, SafeswapPair } from "../src/implmentation/SafeswapFactory.sol";
import { SafeswapRouterProxy1 } from "../src/implmentation/SafeswapRouterProxy1.sol";
import { SafeswapRouterProxy2 } from "../src/implmentation/SafeswapRouterProxy2.sol";
import { FeeJar } from "../src/implmentation/FeeJar.sol";
import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { ISafeswapERC20 } from "../src/interfaces/ISafeswapERC20.sol";


contract SFT is Test {
    Safemoon public safeMoon;
    SafeswapFactory public safeswapFactory;
    SafeswapRouterProxy1 public safeswapRouterProxy1;
    SafeswapRouterProxy2 public safeswapRouterProxy2;
    SafeswapPair public safeswapPair;
    
    SafeSwapTradeRouter public safeSwapTradeRouter;
    FeeJar public feeJar ;
    address public owner;
    address public accountA;
    address public accountB;
    address public accountC;
    address public WETH = 0x4200000000000000000000000000000000000006;
    // base weth : 0x4200000000000000000000000000000000000006
    // 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf

        struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
        }

    function setUp() public {
        safeMoon = new Safemoon();
        safeMoon.initialize();
        owner = safeMoon.owner();

        safeswapPair = new SafeswapPair();
        safeswapFactory = new SafeswapFactory();
        safeswapFactory.initialize(owner, owner); // feeTo, feeToSetter
        safeswapFactory.setImplementation(address(safeswapPair));
        
        safeswapRouterProxy1 = new SafeswapRouterProxy1();
        safeswapRouterProxy1.initialize(address(safeswapFactory), WETH); // _factory, _WETH
        safeswapFactory.setRouter(address(safeswapRouterProxy1));
        safeswapFactory.approveLiquidityPartner(owner);
        safeswapFactory.approveLiquidityPartner(address(safeMoon));

        safeMoon.setWhitelistMintBurn(owner, true);
        safeMoon.setBridgeBurnAddress(owner);

        feeJar = new FeeJar();
        feeJar.initialize(
        address(owner),  // _feeJarAdmin
        address(owner),  // _feeSetter
        address(owner),  // _buyBackAndBurnFeeCollector
        address(owner),  // _lpFeeCollector
        address(safeswapFactory),  // _factory
        10000,                                      // _maxPercentage (100%)
        100,                                        // _buyBackAndBurnFee (1%)
        100,                                         // _lpFee (0.5%)
        100                                          // _supportFee (0.5%)
        );

        safeSwapTradeRouter = new SafeSwapTradeRouter();
        safeSwapTradeRouter.initialize(address(feeJar), address(safeswapRouterProxy1), 10, 100);

        safeswapRouterProxy1.setRouterTrade(address(safeSwapTradeRouter));

        safeswapRouterProxy2 = new SafeswapRouterProxy2();
        safeswapRouterProxy1.setImpls(1,address(safeswapRouterProxy2));

        safeMoon.initRouterAndPair(address(safeswapRouterProxy1));

        // 임의의 계정 A와 B를 생성합니다.
        accountA = vm.addr(1);
        accountB = vm.addr(2);
        accountC = vm.addr(3);

        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("A : " , accountA);
        console.log("B : " , accountB);
        console.log("C : " , accountC);

        // 각 계정에 이더를 할당합니다.
        vm.deal(accountA, 100 ether);
        vm.deal(accountB, 100 ether);
        vm.deal(accountC, 100 ether);
    }

    function test_Mint() public {
           // owner 계정에서 민팅
        vm.prank(owner); // owner로 행동을 시뮬레이션
        safeMoon.mint(accountA, 100 * 10 ** 9); // A 계정에 1000 토큰 민팅
        safeMoon.mint(accountB, 200 * 10 ** 9); // B 계정에 2000 토큰 민팅
        safeMoon.mint(accountC, 300 * 10 ** 9); // B 계정에 2000 토큰 민팅

        ISafeswapERC20 v2pair = ISafeswapERC20(0x7cDAe6c8861BBCf9bc66eFcDFFb3AA1D1d2644f8);
        console.log("Before LP Account A:", accountA);
        console.log("Abal : " , address(accountA).balance, safeMoon.balanceOf(accountA));
        console.log(v2pair.balanceOf(accountA));
        vm.prank(accountA);        
        safeMoon.approve(address(safeswapRouterProxy1), 100 * 10 ** 9);
        vm.prank(accountA);        
        safeswapRouterProxy1.addLiquidityETH{value: 100 ether}(address(safeMoon), 100 * 10 ** 9,0,0,accountA,0);
        console.log("After LP Account A:", accountA);
        console.log("Abal : " , address(accountA).balance, safeMoon.balanceOf(accountA));
        console.log(v2pair.balanceOf(accountA));

        console.log("Bbal : " , safeMoon.balanceOf(accountB));
        console.log("Cbal : " , safeMoon.balanceOf(accountC));

        //         struct Trade {
        // uint256 amountIn;
        // uint256 amountOut;
        // address[] path;
        // address payable to;
        // uint256 deadline;
        // }

        SafeSwapTradeRouter.Trade memory temp;
        temp.amountIn = 50 * 10 ** 9;
        temp.amountOut = 1 * 10 ** 18;
        
        address[] memory temp2 = new address[](2);
        temp2[0] = address(safeMoon);
        temp2[1] = WETH;

        temp.to = payable(accountB);
        temp.deadline = block.timestamp + 1000 ;


        vm.prank(accountB);
        safeMoon.approve(address(safeSwapTradeRouter), 100 * 10 ** 9);
        vm.prank(accountB);
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount(temp);
        
    }

}