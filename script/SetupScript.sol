// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import { Safemoon } from "../src/implmentation/Safemoon.sol";
import { SafeswapFactory, SafeswapPair } from "../src/implmentation/SafeswapFactory.sol";
import { SafeswapRouterProxy1 } from "../src/implmentation/SafeswapRouterProxy1.sol";
import { SafeswapRouterProxy2 } from "../src/implmentation/SafeswapRouterProxy2.sol";
import { FeeJar } from "../src/implmentation/FeeJar.sol";
import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { ISafeswapERC20 } from "../src/interfaces/ISafeswapERC20.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console } from "forge-std/Script.sol";

contract TestSetup is Script {
    
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
    }

    function _setupUsers() internal {
        /* User */
        vm.label(accountA, "accountA");
        vm.label(accountB, "accountB");
        vm.label(accountC, "accountC");

        /* owners */
        feeToSetter = makeAddr("feeToSetter");
        feeTo = makeAddr("feeTo");

        vm.label(owner, "owner");
        vm.label(feeToSetter, "feeToSetter");
        vm.label(feeTo, "feeTo");
    }

    function _deployContracts() internal {
        
        vm.startBroadcast(pvk_Owner);

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

        vm.stopBroadcast();
    }

    function _initializeAndSetConfigs() internal {
        vm.startBroadcast(owner);

        /* SafeMoon */
        //! safeMoon 초기화 -> 매수 매도시 2.5% TAX , 2.5%는 LP 제공 + 번을 위해 feeSetter로 전송
        //! 테스트를 위해 기존 코드 수정 __Safemoon_tiers_init
        //!  excludeFromReward -> require(!_isExcluded[account], "Invalid"); 제거
        safeMoon.initialize();
        safeMoon.setWhitelistMintBurn(owner, true);
        safeMoon.setBridgeBurnAddress(owner);

        /* SafeswapRouterProxy1 */
        safeswapRouterProxy1.initialize(address(safeswapFactory), WETH); // TODO: impl인지 proxy인지 확인
        
        /* SafeswapFactory */
        safeswapFactory.initialize(owner, owner); // feeTo, feeToSetter
        safeswapFactory.setImplementation(address(safeswapPair));
        safeswapFactory.setRouter(address(safeswapRouterProxy1));
        safeswapFactory.approveLiquidityPartner(owner);
        safeswapFactory.approveLiquidityPartner(address(safeMoon));

        /* FeeJar */
        // uniswap을 쓸 수도 있기 때문에 모든 수수로 0
        feeJar.initialize(
            address(owner),            // _feeJarowner
            address(owner),            // _feeSetter
            address(owner),            // _buyBackAndBurnFeeCollector
            address(owner),            // _lpFeeCollector
            address(safeswapFactory),  // _factory
            10000,                     // _maxPercentage (100%)
            0,                       // _buyBackAndBurnFee (1%)
            0,                       // _lpFee (0.5%)
            0                        // _supportFee (0.5%)
        );

        /* SafeSwapTradeRouter */
        // uniswap을 쓸 수도 있기 때문에 모든 dex 수수로 0 + token fee로
        safeSwapTradeRouter.initialize(address(feeJar), address(safeswapRouterProxy1), 0, 100);
        
        /* SafeswapRouterProxy1 */
        safeswapRouterProxy1.setRouterTrade(address(safeSwapTradeRouter));
        safeswapRouterProxy1.setImpls(1,address(safeswapRouterProxy2Impl));
        safeswapRouterProxy1.setWhitelist(address(safeSwapTradeRouter),true);

        safeMoon.initRouterAndPair(address(safeswapRouterProxy1));
        vm.stopBroadcast();

        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("A : " , accountA);
        console.log("B : " , accountB);
        console.log("C : " , accountC);
    }

}