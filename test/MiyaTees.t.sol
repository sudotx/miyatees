// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Test} from "@forge/Test.sol";
import {MiyaTees} from "@src/MiyaTees.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";

contract MiyaTeeTest is Test {
    event RefundPaid();
    event BidPlaced(address indexed sender, uint256 amount);
    event AuctionStarted(uint256 endTime);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    MiyaTees public miyaTees;
    MockERC721 token;

    address seller;

    function setUp() public {
        token = new MockERC721("MiyaTee", "MYT"); // miya tee

        seller = address(0x1337);
        vm.deal(address(seller), 1 ether);

        token.mint(address(seller), 1337); // mint the token to the seller

        miyaTees = new MiyaTees(payable(address(seller)), address(token), 1337);
    }

    function testAuctionCanStart() public {
        vm.startPrank(seller);
        token.approve(address(miyaTees), 1337);
        vm.expectEmit(false, false, false, true);
        emit AuctionStarted(block.timestamp + miyaTees.AUCTION_DURATION());
        miyaTees.startAuction();
        vm.stopPrank();
        assertEq(miyaTees.endAt(), block.timestamp + miyaTees.AUCTION_DURATION());
    }

    function testUsersCanBid() public {
        testAuctionCanStart();
        vm.deal(address(2), 1 ether);
        vm.prank(address(2));
        miyaTees.bidTees{value: 0.5 ether}();
    }

    function testFailIfNextBidderDoesNotPayMoreThanPreviousBidder() public {
        testUsersCanBid();
        vm.deal(address(3), 1 ether);
        vm.prank(address(3));
        miyaTees.bidTees{value: 0.5 ether}();
    }

    function testNextUserPaysTheAllotedBidIncrement() public {
        testUsersCanBid();
        vm.deal(address(4), 1 ether);
        vm.prank(address(4));
        miyaTees.bidTees{value: 0.5 ether + miyaTees.BID_INCREMENT()}();
    }

    function testAuctionCanEnd() public {
        testAuctionCanStart();
        vm.prank(address(seller));
        miyaTees.endAt();
        vm.roll(miyaTees.endAt());
        miyaTees.endAuction();
    }

    function testFailIfUserTriesBiddingAfterAuctionIsClosed() public {
        testAuctionCanEnd();
        vm.deal(address(6), 1 ether);
        vm.prank(address(6));
        miyaTees.bidTees{value: 0.5 ether + miyaTees.BID_INCREMENT()}();
    }

    function testFailIfUserBidsWithALowBalance() public {
        testAuctionCanStart();
        vm.prank(address(7));
        miyaTees.bidTees{value: 0.001 ether}();
    }

    function testBidRefundsWork() public {
        // lmao doesnt work asf
    }

    function testAuctionEndsWithSellerGettingEthSentToTheContract() public {
        testUsersCanBid();
        vm.prank(address(seller));
        miyaTees.endAuction();
        assertEq(address(miyaTees).balance, 0.5 ether);
    }

    function testAuctionCannotSettleBeforeAuctionEnds() public {}
}
