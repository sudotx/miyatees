// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {Test, console} from "@forge/Test.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";

// import weth interface

contract MiyaTeesFuzzTest is Test {
    uint256 constant MAX = type(uint256).max;
    MiyaTeesAuction public miyaTees;
    MockERC721 public mockToken;

    function setUp() public {}

    function testFuzz_createBid() public {}
    function testFuzz_addLiquidity() public {}
    function testFuzz_removeLiquidity() public {}
    function testFuzz_settleAuction() public {}
    function testFuzz_createAuction() public {}
    function testFuzz_tweakProtocolValues() public {}
    function testFuzz_tweakOnlyOwnerFunctions() public {}
}
