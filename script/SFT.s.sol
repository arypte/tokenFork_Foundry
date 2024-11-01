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
    address feeseter = 0xbf22b27ceC1F1c8fc04219ccCCb7ED6F6F4f8030;


    Safemoon public safeMoon;
    SafeswapFactory public safeswapFactory;
    SafeswapRouterProxy1 public safeswapRouterProxy1;
    SafeswapRouterProxy2 public safeswapRouterProxy2;
    SafeswapPair public safeswapPair;

    SafeSwapTradeRouter public safeSwapTradeRouter;
    FeeJar public feeJar;
    address public WETH = 0x4200000000000000000000000000000000000006;
    uint256 decimal;
    ISafeswapERC20 v2pair;

    function setupContract() public { 

        vm.startBroadcast(pvk_Owner);

        safeMoon = new Safemoon();
        // safeMoon 초기화
        //! 테스트를 위해 기존 코드 수정 __Safemoon_tiers_init
        //!  excludeFromReward -> require(!_isExcluded[account], "Invalid"); 제거
        safeMoon.initialize();
        decimal = 10 ** safeMoon.decimals();

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

        //! FeeJar 확인 수수료체크
        feeJar = new FeeJar();
        feeJar.initialize(
            address(owner),  // _feeJarAdmin
            address(owner),  // _feeSetter
            address(owner),  // _buyBackAndBurnFeeCollector
            address(owner),  // _lpFeeCollector
            address(safeswapFactory),  // _factory
            10000,                                   // _maxPercentage (100%)
            0,                                       // _buyBackAndBurnFee (1%)
            0,                                       // _lpFee (0.5%)
            0                                        // _supportFee (0.5%)
        );

        safeSwapTradeRouter = new SafeSwapTradeRouter();
        
        //! DexFee 체크
        safeSwapTradeRouter.initialize(address(feeJar), address(safeswapRouterProxy1), 0, 100);

        safeswapRouterProxy1.setRouterTrade(address(safeSwapTradeRouter));

        safeswapRouterProxy2 = new SafeswapRouterProxy2();
        safeswapRouterProxy1.setImpls(1,address(safeswapRouterProxy2));
        safeswapRouterProxy1.setWhitelist(address(safeSwapTradeRouter),true);

        safeMoon.initRouterAndPair(address(safeswapRouterProxy1));
        
        // safeMoon.mint(accountA, 1000000 * 10**6 * decimal); // A 계정에 토큰 전체 민팅
        safeMoon.whitelistAddress(address(safeSwapTradeRouter), 1);

        vm.stopBroadcast();

        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("safeswapPair : " , address(safeswapPair), "\n\n");

        console.log("setup safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("setup safeMoon owner bal :" , safeMoon.balanceOf(owner));
    }

    function addLiquidity() public {

        //! 모든 토큰을 1이더로 lp 제공
        // vm.startBroadcast(p);
        vm.startBroadcast(pvk_Owner);
        safeMoon.approve(address(safeswapRouterProxy1), 1000000 * 10**6 * decimal);
        safeswapRouterProxy1.addLiquidityETH{value: 1 ether}(address(safeMoon), 1000000 * 10 ** 6 * decimal,0,0,owner,0);
        vm.stopBroadcast();

        address pairAddr = safeswapFactory.getPair(address(safeMoon),WETH);
        v2pair = ISafeswapERC20(pairAddr);

        console.log("After AddLiquidity safeMoon owner bal :" , safeMoon.balanceOf(owner), "\n");
        console.log("After AddLiquidity lp owner bal :" , v2pair.balanceOf(owner), "\n");
    }

    function swapSFTwithDEX() public {
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

        temp.to = payable(accountB);
        temp.deadline = block.timestamp + 1000 ;

        console.log("Before Trade safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("Before Trade ETH B bal :" , accountB.balance , "\n");

        vm.startBroadcast(pvk_B);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), 2000 * decimal);
        // safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(temp);
        safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.1 ether}(temp, 0);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        console.log("After Trade safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("after Trade ETH B bal :" , accountB.balance, "\n");

        temp.amountIn = safeMoon.balanceOf(accountB);
        temp.amountOut = 0;
        
        temp2[0] = address(safeMoon);
        temp2[1] = WETH;
        temp.path = temp2;

        temp.to = payable(accountB);
        temp.deadline = block.timestamp + 1000 ;

        vm.startBroadcast(pvk_B);
        //! approve safeswapRouterProxy1   , safeSwapTradeRouter 아님
        safeMoon.approve(address(safeswapRouterProxy1), safeMoon.balanceOf(accountB));
        safeSwapTradeRouter.swapExactTokensForETHAndFeeAmount{value: 0.1 ether}(temp);
        // safeSwapTradeRouter.swapExactETHForTokensWithFeeAmount{value: 0.11 ether}(temp, 1 * 10 ** 16);
        // swapExactETHForTokensWithFeeAmount(Trade memory trade, uint256 _feeAmount);
        vm.stopBroadcast();

        console.log("After2 Trade safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("after2 Trade ETH B bal :" , accountB.balance ,"\n\n");
    }

    function transfertest() public {

        console.log("before transfer safeMoon owner bal :" , safeMoon.balanceOf(owner));
        console.log("before transfer safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("before transfer safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("before transfer safeMoon C bal :" , safeMoon.balanceOf(accountC));

        console.log("before transfer safeMoon commission bal :" , safeMoon.balanceOf(feeseter));
        
        
        vm.startBroadcast(pvk_C);
        safeMoon.transfer(accountB, 1000 * decimal);
        vm.stopBroadcast();

        console.log("after transfer safeMoon owner bal :" , safeMoon.balanceOf(owner));
        console.log("after transfer safeMoon A bal :" , safeMoon.balanceOf(accountA));
        console.log("after transfer safeMoon B bal :" , safeMoon.balanceOf(accountB));
        console.log("after transfer safeMoon C bal :" , safeMoon.balanceOf(accountC));

        console.log("after transfer safeMoon commission bal :" , safeMoon.balanceOf(feeseter));
        

    }
    
    function run() public {
        setupContract();

        addLiquidity();

        swapSFTwithDEX();

        // transfertest();

        // console.log()
    }
}
