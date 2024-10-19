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
    // 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf

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

        _fundSFT();
    }

    function _setupUsers() internal {
        /* User */
        accountA = makeAddr("accountA");
        accountB = makeAddr("accountB");
        accountC = makeAddr("accountC");

        vm.deal(accountA, INITIAL_BALANCE);
        vm.deal(accountB, INITIAL_BALANCE);
        vm.deal(accountC, INITIAL_BALANCE);

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
        safeMoon = Safemoon(payable(address(new ERC1967Proxy(safeMoonImpl, ""))));
        safeswapFactory = SafeswapFactory(payable(address(new ERC1967Proxy(safeswapFactoryImpl, ""))));
        // safeswapPair = SafeswapPair(payable(address(new ERC1967Proxy(safeswapPairImpl, ""))));
        safeswapPair = SafeswapPair(safeswapPairImpl);
        safeswapRouterProxy1 = SafeswapRouterProxy1(payable(address(new ERC1967Proxy(safeswapRouterProxy1Impl, ""))));
        safeswapRouterProxy2 = SafeswapRouterProxy2(payable(address(new ERC1967Proxy(safeswapRouterProxy2Impl, ""))));
        safeSwapTradeRouter = SafeSwapTradeRouter(payable(address(new ERC1967Proxy(safeSwapTradeRouterImpl, ""))));
        feeJar = FeeJar(payable(address(new ERC1967Proxy(feeJarImpl, ""))));

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
        vm.startPrank(owner);

        /* SafeMoon */
        safeMoon.initialize();
        safeMoon.setWhitelistMintBurn(owner, true);
        safeMoon.setBridgeBurnAddress(owner);
        assertEq(safeMoon.owner(), owner, "SafeMoon: owner is not owner");

        /* SafeswapRouterProxy1 */
        safeswapRouterProxy1.initialize(address(safeswapFactory), WETH); // TODO: impl인지 proxy인지 확인
        
        /* SafeswapFactory */
        safeswapFactory.initialize(owner, owner); // feeTo, feeToSetter
        safeswapFactory.setImplementation(address(safeswapPair));
        safeswapFactory.setRouter(address(safeswapRouterProxy1));
        safeswapFactory.approveLiquidityPartner(owner);
        safeswapFactory.approveLiquidityPartner(address(safeMoon));

        /* FeeJar */
        feeJar.initialize(
            address(owner),            // _feeJarowner
            address(owner),            // _feeSetter
            address(owner),            // _buyBackAndBurnFeeCollector
            address(owner),            // _lpFeeCollector
            address(safeswapFactory),  // _factory
            10000,                     // _maxPercentage (100%)
            100,                       // _buyBackAndBurnFee (1%)
            100,                       // _lpFee (0.5%)
            100                        // _supportFee (0.5%)
        );

        /* SafeSwapTradeRouter */
        safeSwapTradeRouter.initialize(address(feeJar), address(safeswapRouterProxy1), 10, 100);
        
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

    function _fundSFT() internal {
        // owner 계정에서 민팅
        vm.startPrank(owner); // owner로 행동을 시뮬레이션
        safeMoon.mint(accountA, 10000 * SFT_DECIMAL); // A 계정에 10000 토큰 민팅
        safeMoon.mint(accountB, 20000 * SFT_DECIMAL); // B 계정에 20000 토큰 민팅
        safeMoon.mint(accountC, 30000 * SFT_DECIMAL); // B 계정에 30000 토큰 민팅
        vm.stopPrank();
    }
}