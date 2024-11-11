// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import {Test, console} from "forge-std/Test.sol";
import {Safemoon} from "../src/implmentation/Safemoon.sol";
import {SafeswapFactory, SafeswapPair} from "../src/implmentation/SafeswapFactory.sol";
import {SafeswapRouterProxy1} from "../src/implmentation/SafeswapRouterProxy1.sol";
import {SafeswapRouterProxy2} from "../src/implmentation/SafeswapRouterProxy2.sol";
import {FeeJar} from "../src/implmentation/FeeJar.sol";
import {SafeSwapTradeRouter} from "../src/implmentation/SafeSwapTradeRouter.sol";
import {ISafeswapERC20} from "../src/interfaces/ISafeswapERC20.sol";
import {TestSetup} from "./SetupScript.sol";

contract DeploySFT is TestSetup {

    ISafeswapERC20 v2pair;

    function run() public {

        // ERC20 초기 세팅, 수수료, 물량 등
        _testSetup();
        console.log("1 commision fee" , safeMoon.balanceOf(address(feeVault)));

        // DEX 유동성 제공(owner 물량 + 1이더 Lp 생성)
        addLiquidity();
        console.log("2 commision fee" , safeMoon.balanceOf(address(feeVault)));

        // DEX 통해서 유저 A , B 가 밈코 구매
        buySFTwithDEX();
        console.log("3 commision fee" , safeMoon.balanceOf(address(feeVault)));

        // DEX 통해서 유저 B가 매도, A 잔고 증가 확인
        sellSFTwithDEX();
        console.log("4 commision fee" , safeMoon.balanceOf(address(feeVault)));

        // transfertest();

        feeWithdraw();
    }

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

    function buySFTwithDEX() public {
        /*
        struct Trade {
            uint256 amountIn;
            uint256 amountOut;
            address[] path;
            address payable to;
            uint256 deadline;
        }
        */
        
        SafeSwapTradeRouter.Trade memory temp;
        temp.amountIn = 1 * 10 ** 17;
        temp.amountOut = 0;
        
        address[] memory temp2 = new address[](2);
        temp2[1] = address(safeMoon);
        temp2[0] = WETH;
        temp.path = temp2;

        temp.to = payable(accountA);
        temp.deadline = block.timestamp + 1000 ;

        console.log("Before Buy safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("Before Buy safeMoon A bal :" , safeMoon.balanceOf(accountB));
        console.log("Before Buy ETH B bal :" , accountB.balance , "\n");

        vm.startBroadcast(pvk_A);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), safeMoon.balanceOf(accountB));
        // safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(temp);
        safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.1 ether}(temp, 0);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        temp.to = payable(accountB);

        vm.startBroadcast(pvk_B);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), 2000 * SFT_DECIMAL);
        // safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(temp);
        safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.1 ether}(temp, 0);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        console.log("After Buy safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("After Buy safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("After Buy ETH B bal :" , accountB.balance, "\n\n");
    }

    function sellSFTwithDEX() public {

        SafeSwapTradeRouter.Trade memory temp;
        address[] memory temp2 = new address[](2);
        temp.amountIn = safeMoon.balanceOf(accountB);
        temp.amountOut = 0;
        
        temp2[0] = address(safeMoon);
        temp2[1] = WETH;
        temp.path = temp2;

        temp.to = payable(accountB);
        temp.deadline = block.timestamp + 1000 ;

        uint256 beforeAaccount = safeMoon.balanceOf(accountA);
        console.log("Before Sell safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("Before Sell safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("Before Sell ETH B bal :" , accountB.balance ,"\n\n");

        vm.startBroadcast(pvk_B);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), safeMoon.balanceOf(accountB));
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(temp);
        // safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.11 ether}(temp, 1 * 10 ** 16);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        console.log("After Sell safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("A balance incresment : ", safeMoon.balanceOf(accountA) - beforeAaccount);
        console.log("After Sell safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("After Sell ETH B bal :" , accountB.balance ,"\n\n");
    }

    function transfertest() public {

        console.log("before transfer safeMoon owner bal :" , safeMoon.balanceOf(owner));
        console.log("before transfer safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("before transfer safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("before transfer safeMoon C bal :" , safeMoon.balanceOf(accountC));

        console.log("before transfer safeMoon commission bal :" , safeMoon.balanceOf(address(feeVault)));
        
        vm.startBroadcast(pvk_B);
        safeMoon.transfer(accountC, 1000 * SFT_DECIMAL);
        vm.stopBroadcast();

        console.log("after transfer safeMoon owner bal :" , safeMoon.balanceOf(owner));
        console.log("after transfer safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("after transfer safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("after transfer safeMoon C bal :" , safeMoon.balanceOf(accountC));

        console.log("after transfer safeMoon commission bal :" , safeMoon.balanceOf(address(feeVault)));

        // console.log(safeMoon._defaultFees());
    }

    function feeWithdraw() public{

        vm.startBroadcast(pvk_Owner);

        console.log("before transfer owner balane" , safeMoon.balanceOf(owner));

        feeVault.withdrawToken(safeMoon.balanceOf(address(feeVault)));

        console.log("after transfer owner balane" , safeMoon.balanceOf(owner));

        payable(address(feeVault)).transfer(1 ether);

        console.log("before transfer owner balane" , address(owner).balance);

        feeVault.withdrawNative(1 ether);

        console.log("after transfer owner balane" , address(owner).balance);

        vm.stopBroadcast();
        
    }

}
