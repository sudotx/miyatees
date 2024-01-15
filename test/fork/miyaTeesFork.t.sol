// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {Test, console} from "@forge/Test.sol";

// test with actual collections, on mainnet

// test with milady, bonkler, apes, and a basket of other tokens

contract MiyaTeesForkTest is Test {
    MiyaTeesAuction public miyaTees;

    function setUp() public {
        uint256 mainnetFork = vm.createSelectFork("mainnet", 42_000_069);
        console.log(mainnetFork);
    }

    function testFork_createAuctionWorks() public {}
    function testFork_settleAuctionWorks() public {}
    function testFork_FundsPayoutSuccessfully() public {}
    function testFork_SendsNftInCorrectly() public {}
    function testFork_SendsNftOutCorrectly() public {}
    function testFork_AuctionParametersAreSetCorrectlyOnConstruction() public {}
    function testFork_OnlyOwnerCanSetAuctionParameters() public {}
}
