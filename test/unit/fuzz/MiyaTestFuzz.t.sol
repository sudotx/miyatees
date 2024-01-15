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

    function setUp() public {
        console.log("setting up...");

        mockToken = new MockERC721("MiyaTee", "MT");
        vm.label(address(mockToken), "MOCK_MIYATEE");
        mockToken.mint(address(1), 1337);

        miyaTees = new MiyaTeesAuction(payable(address(0)), address(mockToken), 1337, 1, 1);
        vm.label(address(miyaTees), "MIYATEES_AUCTION");

        vm.label(address(this), "THE_FUZZINATOR");
    }

    function testFuzz_createBid() public {}
    function testFuzz_addLiquidity() public {}
    function testFuzz_removeLiquidity() public {}
    function testFuzz_settleAuction() public {}
    function testFuzz_createAuction() public {}
    function testFuzz_tweakProtocolValues() public {}
    function testFuzz_tweakOnlyOwnerFunctions() public {}
}
