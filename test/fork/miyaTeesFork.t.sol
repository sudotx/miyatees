// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {Test, console} from "@forge/Test.sol";

contract MiyaTeesForkTest is Test {
    MiyaTeesAuction public miyaTees;

    function setUp() public {
        uint256 mainnetFork = vm.createSelectFork("mainnet");
        console.log(mainnetFork);
    }
}
