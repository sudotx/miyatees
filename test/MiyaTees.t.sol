// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MiyaTees} from "../src/MiyaTees.sol";

contract CounterTest is Test {
    MiyaTees public miyaTees;

    function setUp() public {
        miyaTees = new MiyaTees();
    }
}
