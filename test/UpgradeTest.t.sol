// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import { TestSetup } from "./TestSetup.t.sol";

import {Test, console} from "forge-std/Test.sol";
import { Safemoon } from "../src/implmentation/Safemoon.sol";
import { SafeswapFactory, SafeswapPair } from "../src/implmentation/SafeswapFactory.sol";
import { SafeswapRouterProxy1 } from "../src/implmentation/SafeswapRouterProxy1.sol";
import { SafeswapRouterProxy2 } from "../src/implmentation/SafeswapRouterProxy2.sol";
import { FeeJar } from "../src/implmentation/FeeJar.sol";
import { SafeSwapTradeRouter } from "../src/implmentation/SafeSwapTradeRouter.sol";
import { ISafeswapERC20 } from "../src/interfaces/ISafeswapERC20.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";


contract UpgradeTest is TestSetup {
    address public safeMoonImplNew;
    address public safeswapFactoryImplNew;
    address public safeswapPairImplNew;
    address public safeswapRouterProxy1ImplNew;
    address public safeswapRouterProxy2ImplNew;
    address public safeSwapTradeRouterImplNew;
    address public feeJarImplNew;

    function setUp() public {
        _testSetup();
    }

    function testProxyAdmin() view public {
        address adminStored;

        adminStored = ProxyAdmin(proxyAdmin).getProxyAdmin(ITransparentUpgradeableProxy(address(safeMoon)));
        assertEq(adminStored, proxyAdmin, "safeMoon proxyAdmin is not proxyAdmin");

        adminStored = ProxyAdmin(proxyAdmin).getProxyAdmin(ITransparentUpgradeableProxy(address(safeswapFactory)));
        assertEq(adminStored, proxyAdmin, "safeswapFactory proxyAdmin is not proxyAdmin");

        adminStored = ProxyAdmin(proxyAdmin).getProxyAdmin(ITransparentUpgradeableProxy(address(safeswapRouterProxy1)));
        assertEq(adminStored, proxyAdmin, "safeswapRouterProxy1 proxyAdmin is not proxyAdmin");

        adminStored = ProxyAdmin(proxyAdmin).getProxyAdmin(ITransparentUpgradeableProxy(address(safeswapRouterProxy2)));
        assertEq(adminStored, proxyAdmin, "safeswapRouterProxy2 proxyAdmin is not proxyAdmin");

        adminStored = ProxyAdmin(proxyAdmin).getProxyAdmin(ITransparentUpgradeableProxy(address(safeSwapTradeRouter)));
        assertEq(adminStored, proxyAdmin, "safeSwapTradeRouter proxyAdmin is not proxyAdmin");

        adminStored = ProxyAdmin(proxyAdmin).getProxyAdmin(ITransparentUpgradeableProxy(address(feeJar)));
        assertEq(adminStored, proxyAdmin, "feeJar proxyAdmin is not proxyAdmin");
    }

    function testUpgradeImpl() public {
        vm.startPrank(owner);
        
        /* Deploy Impl */
        safeMoonImplNew = address(new Safemoon());
        safeswapFactoryImplNew = address(new SafeswapFactory());
        safeswapPairImplNew = address(new SafeswapPair());
        safeswapRouterProxy1ImplNew = address(new SafeswapRouterProxy1());
        safeswapRouterProxy2ImplNew = address(new SafeswapRouterProxy2());
        safeSwapTradeRouterImplNew = address(new SafeSwapTradeRouter());
        feeJarImplNew = address(new FeeJar());

        /* Upgrade Impl */
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(safeMoon)), safeMoonImplNew);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(safeswapFactory)), safeswapFactoryImplNew);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(safeswapRouterProxy1)), safeswapRouterProxy1ImplNew);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(safeswapRouterProxy2)), safeswapRouterProxy2ImplNew);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(safeSwapTradeRouter)), safeSwapTradeRouterImplNew);
        ProxyAdmin(proxyAdmin).upgrade(ITransparentUpgradeableProxy(address(feeJar)), feeJarImplNew);

        /* Check Impl */
        assertEq(ITransparentUpgradeableProxy(address(safeMoon)).implementation(), safeMoonImplNew, "safeMoon implementation is not new");
        assertEq(ITransparentUpgradeableProxy(address(safeswapFactory)).implementation(), safeswapFactoryImplNew, "safeswapFactory implementation is not new");
        assertEq(ITransparentUpgradeableProxy(address(safeswapRouterProxy1)).implementation(), safeswapRouterProxy1ImplNew, "safeswapRouterProxy1 implementation is not new");
        assertEq(ITransparentUpgradeableProxy(address(safeswapRouterProxy2)).implementation(), safeswapRouterProxy2ImplNew, "safeswapRouterProxy2 implementation is not new");
        assertEq(ITransparentUpgradeableProxy(address(safeSwapTradeRouter)).implementation(), safeSwapTradeRouterImplNew, "safeSwapTradeRouter implementation is not new");
        assertEq(ITransparentUpgradeableProxy(address(feeJar)).implementation(), feeJarImplNew, "feeJar implementation is not new");

        vm.stopPrank();
    }
}