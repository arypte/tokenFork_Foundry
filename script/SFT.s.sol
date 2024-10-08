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

import {Script} from "forge-std/Script.sol";

contract DeploySFT is Script {

    // Load private keys from .env
    uint256 pvk_A = vm.envUint("Pvk_A");
    uint256 pvk_B = vm.envUint("Pvk_B");
    uint256 pvk_C = vm.envUint("Pvk_C");
    uint256 pvk_Owner = vm.envUint("Pvk_Owner");

    // Convert private keys to addresses
    address accountA = vm.addr(pvk_A);
    address accountB = vm.addr(pvk_B);
    address accountC = vm.addr(pvk_C);
    address owner = vm.addr(pvk_Owner);

    Safemoon public safeMoon;
    SafeswapFactory public safeswapFactory;
    SafeswapRouterProxy1 public safeswapRouterProxy1;
    SafeswapRouterProxy2 public safeswapRouterProxy2;
    SafeswapPair public safeswapPair;

    SafeSwapTradeRouter public safeSwapTradeRouter;
    FeeJar public feeJar;
    address public WETH = 0x4200000000000000000000000000000000000006;
    function run() public {
        vm.startBroadcast(pvk_Owner);

        safeMoon = new Safemoon();
        // safeMoon 초기화
        //! 테스트를 위해 기존 코드 수정 __Safemoon_tiers_init
        //!  excludeFromReward -> require(!_isExcluded[account], "Invalid"); 제거
        safeMoon.initialize();

        safeswapPair = new SafeswapPair();
        safeswapFactory = new SafeswapFactory();
        
        //! feeTo, feeToSetter 체크
        safeswapFactory.initialize(owner, owner); // feeTo, feeToSetter
        safeswapFactory.setImplementation(address(safeswapPair));
        
        safeswapRouterProxy1 = new SafeswapRouterProxy1();
        safeswapRouterProxy1.initialize(address(safeswapFactory), WETH); // _factory, _WETH
        safeswapFactory.setRouter(address(safeswapRouterProxy1));

        //! approveLiquidityPartner 체크
        safeswapFactory.approveLiquidityPartner(owner);
        safeswapFactory.approveLiquidityPartner(address(safeMoon));

        safeMoon.setWhitelistMintBurn(owner, true);
        safeMoon.setBridgeBurnAddress(owner);

        //! FeeJar 확인
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
        safeswapRouterProxy1.setWhitelist(address(safeSwapTradeRouter),true);

        safeMoon.initRouterAndPair(address(safeswapRouterProxy1));
        
        safeMoon.mint(accountA, 10000 * 10 ** 9); // A 계정에 1000 토큰 민팅
        safeMoon.mint(accountB, 20000 * 10 ** 9); // B 계정에 2000 토큰 민팅
        safeMoon.mint(accountC, 30000 * 10 ** 9); // B 계정에 2000 토큰 민팅

        vm.stopBroadcast();

        console.log("Before safeMoon C bal :" , safeMoon.balanceOf(accountC));

        vm.startBroadcast(pvk_A);        
        safeMoon.approve(address(safeswapRouterProxy1), 5000 * 10 ** 9);
        safeswapRouterProxy1.addLiquidityETH{value: 5 ether}(address(safeMoon), 5000 * 10 ** 9,0,0,accountA,0);
        vm.stopBroadcast();

        address pairAddr = safeswapFactory.getPair(address(safeMoon),WETH);
        ISafeswapERC20 v2pair = ISafeswapERC20(pairAddr);

        console.log("After LP AddLiquidity safeMoon C bal :" , safeMoon.balanceOf(accountC));

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
        temp.amountIn = 1000 * 10 ** 9;
        temp.amountOut = 1 * 10 ** 17;
        
        address[] memory temp2 = new address[](2);
        temp2[0] = address(safeMoon);
        temp2[1] = WETH;
        temp.path = temp2;

        temp.to = payable(accountB);
        temp.deadline = block.timestamp + 1000 ;

        vm.startBroadcast(pvk_B);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), 2000 * 10 ** 9);
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 1 ether}(temp);
        vm.stopBroadcast();

        console.log("After Trade safeMoon C bal :" , safeMoon.balanceOf(accountC));

        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("safeswapPair : " , address(safeswapPair));
    }
}
