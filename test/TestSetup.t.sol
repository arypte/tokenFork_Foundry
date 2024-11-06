// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import { Test, console } from "forge-std/Test.sol";

import { Safemoon } from "../src/implmentation/Safemoon.sol";
import { SafeswapFactory, SafeswapPair } from "../src/implmentation/SafeswapFactory.sol";
import { SafeswapRouterProxy1 } from "../src/implmentation/SafeswapRouterProxy1.sol";
import { SafeswapRouterProxy2 } from "../src/implmentation/SafeswapRouterProxy2.sol";
import { FeeJar } from "../src/implmentation/FeeJar.sol";
import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { ISafeswapERC20 } from "../src/interfaces/ISafeswapERC20.sol";
import { SFTERC1967Proxy } from "../src/SafeMoonProxy.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestSetup is Test {
    uint256 constant INITIAL_BALANCE = 1000e18; // 1000 ETH
    uint256 constant SFT_DECIMAL = 1e9;

    /* Impl */
    address public safeMoonImpl;
    address public safeswapFactoryImpl;
    address public safeswapRouterProxy1Impl;
    address public safeswapRouterProxy2Impl;
    address public safeswapPairImpl;
    address public safeSwapTradeRouterImpl;
    address public feeJarImpl;

    /* Proxy */
    Safemoon public safeMoon;
    SafeswapFactory public safeswapFactory;
    SafeswapRouterProxy1 public safeswapRouterProxy1;
    SafeswapRouterProxy2 public safeswapRouterProxy2;
    SafeswapPair public safeswapPair;
    SafeSwapTradeRouter public safeSwapTradeRouter;
    FeeJar public feeJar ;
    
    /* User */
    address public accountA;
    address public accountB;
    address public accountC;
    
    /* owner */
    address public owner;
    address public feeToSetter;
    address public feeTo;

    /* Base Contracts */
    address public WETH = 0x4200000000000000000000000000000000000006; // base weth

    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
    }

    function _testSetup() internal {
        // 각 계정들 설정
        _setupUsers();

        // 컨트랙트 배포 (Impl, Proxy)
        _deployContracts();

        // 컨트랙트 config 설정
        _initializeAndSetConfigs();

        // 계정 별 토큰 민트
        _initialmintSFT();
    }

    function _setupUsers() internal {
        /* User */
        accountA = makeAddr("accountA");
        accountB = makeAddr("accountB");
        accountC = makeAddr("accountC");

        //! Native, Token Balance 설정
        vm.deal(accountA, INITIAL_BALANCE);
        vm.deal(accountB, INITIAL_BALANCE);
        vm.deal(accountC, INITIAL_BALANCE);
        // TODO : 발표전에 한번더 테스트
        // ERC20 USDC = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        // deal(address(USDC), accountA, 100 * 10 ** ERC20(USDC).decimals());

        //! 주소 라벨링
        vm.label(accountA, "accountA");
        vm.label(accountB, "accountB");
        vm.label(accountC, "accountC");

        /* owners */
        owner = makeAddr("owner");
        feeToSetter = makeAddr("feeToSetter");
        feeTo = makeAddr("feeTo");

        vm.deal(owner, INITIAL_BALANCE);
        vm.deal(feeToSetter, INITIAL_BALANCE);
        vm.deal(feeTo, INITIAL_BALANCE);

        vm.label(owner, "owner");
        vm.label(feeToSetter, "feeToSetter");
        vm.label(feeTo, "feeTo");
    }

    function _deployContracts() internal {
        vm.startPrank(owner);

        /* Deploy Impl */
        safeMoonImpl = address(new Safemoon());
        safeswapFactoryImpl = address(new SafeswapFactory());
        safeswapPairImpl = address(new SafeswapPair());
        safeswapRouterProxy1Impl = address(new SafeswapRouterProxy1());
        safeswapRouterProxy2Impl = address(new SafeswapRouterProxy2());
        safeSwapTradeRouterImpl = address(new SafeSwapTradeRouter());
        feeJarImpl = address(new FeeJar());

        /* Deploy Proxy */
        safeMoon = Safemoon(payable(address(new SFTERC1967Proxy(safeMoonImpl, ""))));
        safeswapFactory = SafeswapFactory(payable(address(new SFTERC1967Proxy(safeswapFactoryImpl, ""))));
        safeswapPair = SafeswapPair(safeswapPairImpl);
        safeswapRouterProxy1 = SafeswapRouterProxy1(payable(address(new SFTERC1967Proxy(safeswapRouterProxy1Impl, ""))));
        safeswapRouterProxy2 = SafeswapRouterProxy2(payable(address(new SFTERC1967Proxy(safeswapRouterProxy2Impl, ""))));
        safeSwapTradeRouter = SafeSwapTradeRouter(payable(address(new SFTERC1967Proxy(safeSwapTradeRouterImpl, ""))));
        feeJar = FeeJar(payable(address(new SFTERC1967Proxy(feeJarImpl, ""))));

        assertEq(SFTERC1967Proxy(payable(address(safeMoon))).getImplementation(), safeMoonImpl, "safeMoon Impl Not Correct");
        assertEq(SFTERC1967Proxy(payable(address(safeswapRouterProxy1))).getImplementation(), safeswapRouterProxy1Impl, "safeswapRouterProxy1 Impl Not Correct");
        assertEq(SFTERC1967Proxy(payable(address(safeswapRouterProxy2))).getImplementation(), safeswapRouterProxy2Impl, "safeswapRouterProxy2 Impl Not Correct");
        assertEq(SFTERC1967Proxy(payable(address(safeSwapTradeRouter))).getImplementation(), safeSwapTradeRouterImpl, "safeSwapTradeRouter Impl Not Correct");
        assertEq(SFTERC1967Proxy(payable(address(feeJar))).getImplementation(), feeJarImpl, "feeJar Impl Not Correct");

        vm.label(address(safeMoon), "safeMoon");
        vm.label(address(safeswapFactory), "safeswapFactory");
        vm.label(address(safeswapRouterProxy1), "safeswapRouterProxy1");
        vm.label(address(safeswapRouterProxy2), "safeswapRouterProxy2");
        vm.label(address(safeswapPair), "safeswapPair");
        vm.label(address(safeSwapTradeRouter), "safeSwapTradeRouter");
        vm.label(address(feeJar), "feeJar");

        vm.stopPrank();
    }

    function _initializeAndSetConfigs() internal {
        vm.startPrank(owner); // owner로 행동을 시뮬레이션

        /* SafeMoon */
        safeMoon.initialize();
        safeMoon.setWhitelistMintBurn(owner, true);
        safeMoon.setBridgeBurnAddress(owner);

        /* SafeMoon Error */
        assertEq(safeMoon.name(), "SafeMoon", "Token Name Error");
        assertEq(safeMoon.symbol(), "SFM", "Token Symbol Error");
        assertEq(safeMoon.decimals(), 9, "Token Decimal Error");
        assertEq(safeMoon.owner(), owner, "Token Owner Error");

        /* SafeswapRouterProxy1 */
        safeswapRouterProxy1.initialize(address(safeswapFactory), WETH);
        
        /* SafeswapFactory */
        safeswapFactory.initialize(owner, owner); // feeTo, feeToSetter
        safeswapFactory.setImplementation(address(safeswapPair));
        safeswapFactory.setRouter(address(safeswapRouterProxy1));
        safeswapFactory.approveLiquidityPartner(owner);
        safeswapFactory.approveLiquidityPartner(address(safeMoon));

        /* FeeJar */
        feeJar.initialize(
            address(owner),            // _feeJarOwner
            address(owner),            // _feeSetter
            address(owner),            // _buyBackAndBurnFeeCollector
            address(owner),            // _lpFeeCollector
            address(safeswapFactory),  // _factory
            10000,                     // _maxPercentage (100%)
            100,                       // _buyBackAndBurnFee (1%)
            50,                       // _lpFee (0.5%)
            50                        // _supportFee (0.5%)
        );

        /* SafeSwapTradeRouter */
        // DexFee : 0%
        safeSwapTradeRouter.initialize(address(feeJar), address(safeswapRouterProxy1), 0, 100);
        
        /* SafeswapRouterProxy1 */
        safeswapRouterProxy1.setRouterTrade(address(safeSwapTradeRouter));
        safeswapRouterProxy1.setImpls(1,address(safeswapRouterProxy2Impl));
        safeswapRouterProxy1.setWhitelist(address(safeSwapTradeRouter),true);

        safeMoon.initRouterAndPair(address(safeswapRouterProxy1));
        vm.stopPrank();

        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("A : " , accountA);
        console.log("B : " , accountB);
        console.log("C : " , accountC);
    }

    function _initialmintSFT() internal {
        // owner 계정에서 민팅
        vm.startPrank(owner); // owner로 행동을 시뮬레이션
        safeMoon.mint(accountA, 10000 * SFT_DECIMAL); // A 계정에 10000 토큰 민팅
        safeMoon.mint(accountB, 20000 * SFT_DECIMAL); // B 계정에 20000 토큰 민팅
        safeMoon.mint(accountC, 30000 * SFT_DECIMAL); // B 계정에 30000 토큰 민팅
        vm.stopPrank();

        assertEq(safeMoon.balanceOf(accountA), 10000 * SFT_DECIMAL, "Balance Error");
        assertEq(safeMoon.balanceOf(accountB), 20000 * SFT_DECIMAL, "Balance Error");
        assertEq(safeMoon.balanceOf(accountC), 30000 * SFT_DECIMAL, "Balance Error");
    }

    function _printAddress() internal{
        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("A : " , accountA);
        console.log("B : " , accountB);
        console.log("C : " , accountC);
    }
}