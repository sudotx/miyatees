// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {Test, console} from "@forge/Test.sol";

contract MiyaTeesFuzzTest is Test {
    MiyaTeesAuction public miyaTees;

    function setUp() public {
        // console.log(address(miyaTees));
    }
}
