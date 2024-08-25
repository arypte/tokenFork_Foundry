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
    Safemoon public safeMoon;
    SafeswapFactory public safeswapFactory;
    SafeswapRouterProxy1 public safeswapRouterProxy1;
    SafeswapRouterProxy2 public safeswapRouterProxy2;
    SafeswapPair public safeswapPair;

    SafeSwapTradeRouter public safeSwapTradeRouter;
    FeeJar public feeJar;
    address public owner;
    address public WETH = 0x4200000000000000000000000000000000000006;

    function run() public {
        uint DeployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");

        vm.startBroadcast(DeployerPrivateKey);

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
        safeswapRouterProxy1.setWhitelist(address(safeSwapTradeRouter),true);

        safeMoon.initRouterAndPair(address(safeswapRouterProxy1));

        vm.stopBroadcast();

        console.log("Owner:", owner);
        console.log("SFT:", address(safeMoon));
        console.log("safeswapRouterProxy1:", address(safeswapRouterProxy1));
        console.log("factory : " , safeswapRouterProxy1.factory());
        console.log("safeswapPair : " , address(safeswapPair));
    }
}
