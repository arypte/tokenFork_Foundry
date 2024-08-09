// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import {Test, console} from "forge-std/Test.sol";
import { Safemoon } from "../src/implmentation/Safemoon.sol";

contract SFT is Test {
    Safemoon public safeMoon;

    function setUp() public {
        safeMoon = new Safemoon();
    }

    function test_Increment() public {
        console.log(safeMoon.owner());
        safeMoon.initialize();
    }

    function testFuzz_SetNumber(uint256 x) public {
        
    }
}
