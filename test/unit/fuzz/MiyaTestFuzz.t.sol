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

    function testFuzz_createBid(uint256 amount) public {
        // uint256 _amount = this.bound(amount, (10**3), MAX);
    }
    function testFuzz_addLiquidity(uint256 amount) public {}
    function testFuzz_removeLiquidity(uint256 amount) public {}
    function testFuzz_settleAuction(uint256 amount) public {}
    function testFuzz_createAuction(uint256 amount) public {}
    function testFuzz_tweakProtocolValues(uint256 amount) public {}
    function testFuzz_tweakOnlyOwnerFunctions(uint256 amount) public {}

    // create a bound/between function to constrain values and reduce wasted fuzz runs

    // try using echidna here as well..
}
