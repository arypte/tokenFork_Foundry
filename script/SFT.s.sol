// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;


import { Safemoon } from "../src/implmentation/Safemoon.sol";
import { SafeswapFactory, SafeswapPair } from "../src/implmentation/SafeswapFactory.sol";
import { SafeswapRouterProxy1 } from "../src/implmentation/SafeswapRouterProxy1.sol";
import { SafeswapRouterProxy2 } from "../src/implmentation/SafeswapRouterProxy2.sol";
import { FeeJar } from "../src/implmentation/FeeJar.sol";
import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { ISafeswapERC20 } from "../src/interfaces/ISafeswapERC20.sol";
import { SetupScript } from "./SetupScript.s.sol";
import { console } from "forge-std/Script.sol";

contract DeploySFT is SetupScript {

    ISafeswapERC20 v2pair;

    function addLiquidity() public {

        //! 모든 토큰을 1이더로 lp 제공
        // vm.startBroadcast(p);
        vm.startBroadcast(pvk_Owner);
        safeMoon.approve(address(safeswapRouterProxy1), 1000000 * 10**6 * SFT_DECIMAL);
        safeswapRouterProxy1.addLiquidityETH{value: 1 ether}(address(safeMoon), 1000000 * (10 ** 6) * SFT_DECIMAL,0,0,owner,0);
        vm.stopBroadcast();

        address pairAddr = safeswapFactory.getPair(address(safeMoon),WETH);
        v2pair = ISafeswapERC20(pairAddr);

        console.log("After AddLiquidity safeMoon owner bal :" , safeMoon.balanceOf(owner), "\n");
        console.log("After AddLiquidity lp owner bal :" , v2pair.balanceOf(owner), "\n");
    }

    function buySFTwithDEX(uint256 pvk, string memory accountName) public {
        /*
        struct Trade {
            uint256 amountIn;
            uint256 amountOut;
            address[] path;
            address payable to;
            uint256 deadline;
        }
        */
        address addr = vm.addr(pvk);
        
        address[] memory path = new address[](2);
        path[0] = address(safeMoon);
        path[1] = WETH;

        SafeSwapTradeRouter.Trade memory tradeParam = SafeSwapTradeRouter.Trade({
            amountIn: 1 * 10 ** 17,
            amountOut: 0,
            path: path,
            to: payable(addr),
            deadline: block.timestamp + 1000
        });

        console.log("Before Buy safeMoon", accountName, "bal :" , safeMoon.balanceOf(addr));
        console.log("Before Buy ETH", accountName);
        console.log("bal :" , addr.balance , "\n");

        vm.startBroadcast(pvk);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), 2000 * SFT_DECIMAL);
        // safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(temp);
        safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.1 ether}(tradeParam, 0);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        console.log("After Buy safeMoon", accountName, "bal :" , safeMoon.balanceOf(addr));
        console.log("After Buy ETH", accountName);
        console.log("bal :" , addr.balance , "\n");
    }

    function sellSFTwithDEX(uint256 pvk, string memory accountName) public {

        address addr = vm.addr(pvk);

        address[] memory path = new address[](2);
        path[1] = address(safeMoon);
        path[0] = WETH;
        
        SafeSwapTradeRouter.Trade memory tradeParam = SafeSwapTradeRouter.Trade({
            amountIn: safeMoon.balanceOf(addr) / 5,
            amountOut: 0,
            path: path,
            to: payable(addr),
            deadline: block.timestamp + 1000
        });

        console.log("Before Sell safeMoon", accountName, "bal :" , safeMoon.balanceOf(addr));
        console.log("Before Sell ETH", accountName);
        console.log("bal :" , addr.balance , "\n");

        vm.startBroadcast(pvk);
        //! approve safeswapRouterProxy1, safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), safeMoon.balanceOf(accountB));
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(tradeParam);
        // safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.11 ether}(temp, 1 * 10 ** 16);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        console.log("After Sell safeMoon", accountName, "bal :" , safeMoon.balanceOf(addr));
        console.log("After Sell ETH", accountName);
        console.log("bal :" , addr.balance , "\n");
    }

    function balanceCheck() view public {
        console.log("safeMoon owner bal :", safeMoon.balanceOf(owner));
        console.log("Ether owner bal :" ,owner.balance, "\n");

        console.log("safeMoon A bal :", safeMoon.balanceOf(accountA));
        console.log("Ether A bal :", accountA.balance, "\n");

        console.log("safeMoon B bal :", safeMoon.balanceOf(accountB));
        console.log("Ether B bal :", accountB.balance, "\n");

        console.log("safeMoon commission bal :" , safeMoon.balanceOf(feeseter));
    }

    function addSetup() public {
        safeMoon = Safemoon(payable(0x754A91555a8dd5037315ABFd3702ED49d92887b7));
        safeSwapTradeRouter = SafeSwapTradeRouter(payable(0x1fA1618AE2F5b3EcC73692974a5E28926553c032));
        safeswapRouterProxy1 = SafeswapRouterProxy1(payable(0xcC67c99E49EfE35b9e2ED92c6D6Ae7560aDDE714));
        vm.label(address(safeMoon), "safeMoon");
        vm.label(address(safeSwapTradeRouter), "safeSwapTradeRouter");
        vm.label(address(safeswapRouterProxy1), "safeswapRouterProxy1");
    }
    
    function run() public {

        //유저 세팅
        _setupUsers();

        // ERC20 초기 세팅, 수수료, 물량 등
        // _testSetup();
        addSetup();

        // DEX 유동성 제공(owner 물량 + 1이더 Lp 생성)
        // addLiquidity();

        

        // DEX 통해서 유저 A , B 가 밈코 구매
        // buySFTwithDEX(pvk_B, 'B');

        // DEX 통해서 유저 B가 매도, A 잔고 증가 확인
        sellSFTwithDEX(pvk_A, 'A');

        balanceCheck();

        // 158719629998881539726
        // 220136368669001431499
        

        // transfertest();

        // console.log()
    }
}
