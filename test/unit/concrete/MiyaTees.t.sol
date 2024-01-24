// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Test, console, console2} from "@forge/Test.sol";
import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";

contract BadReceiver {
    MiyaTeesAuction myt;

    constructor(address payable _myt) {
        myt = MiyaTeesAuction(_myt);
    }

    function attack(uint256 id) public payable {
        myt.bidTees(id);
        // myt.bidTees{value: msg.value}(id);
    }

    receive() external payable {
        console2.log("bad receiver received: ", msg.value);
        revert();
    }
}

contract MiyaTeeTest is Test {
    event RefundPaid();
    event BidPlaced(address indexed sender, uint256 amount);
    event AuctionStarted(uint256 endTime);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    MiyaTeesAuction public miyaTees;

    MockERC721 token;

    address constant BOB = address(0x2323);
    address constant ALICE = address(0x1212);
    address constant SELLER = address(0x1337);

    uint256 constant TOKENID = 1337;

    modifier prank(address who) {
        vm.startPrank(who);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.label(BOB, "BOB");
        vm.label(ALICE, "ALICE");
        vm.label(SELLER, "SELLER");

        console.log("setting up...");

        vm.startPrank(SELLER);
        token = new MockERC721("MiyaTee", "MYT"); // miya tees
        token.mint(SELLER, TOKENID); // the user has to have the token, to send to the contract
        token.mint(ALICE, 12); // the user has to have the token, to send to the contract
        token.mint(BOB, 13); // the user has to have the token, to send to the contract

        miyaTees = new MiyaTeesAuction(payable(SELLER), address(token), 1337, 1, 1);
        token.approve(address(miyaTees), TOKENID);
        vm.stopPrank();

        vm.label(address(token), "MIYATEE");
        vm.label(address(miyaTees), "MIYATEE_AUCTION");

        console.log("Token Balance Of MiyaTeesAuction", token.balanceOf(address(miyaTees)));
    }

    function testAuctionContractReceivesNeededApprovalAtStartOfAuction() public {
        // check if the auction contract has sufficient token permission
        (address ap) = token.getApproved(TOKENID);
        assertEq(ap, address(miyaTees));
    }

    function testSettleAuctionCannotBeCalledIfItIsBeforeTheAuctionExpiry() public {
        //
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testSettleAuctionCantBeCalledIfTheAuctionTimeIsNotZero() public {
        //
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testSettleAuctionBidderIsNotTheZeroAddress() public {
        //
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testSettleAuctionDataIsSettled() public {
        //
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testAuctionMiyaTeesContractisCorrectlySet() public {
        //
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testAuctionReservePriceisCorrectlySet() public {
        // critica; values should be set
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testAuctionMiyaTeeIDisCorrectlySet() public {
        // critica; values should be set
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testNFTisSentFromTheUserToThisContract() public {
        // fail if nft os not sent to the contract as expected.
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testAuctionhasEndedReturnsFalseWhenAuctionRoundIsOnGoing() public {
        // this should return false
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testAuctionhasEndedReturnsTrueWhenAuctionRoundIsEnded() public {
        // auction ended function should return correctly
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testBidTeesEndsPreviousRunningAuctionRoundCorrectly() public {
        // round should end with certain states being fufullled
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testLastBidderReceivesTheETHSuccesfulyReceivesRefund() public {
        // last bidder receives ETH set to it
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testBidSuccessfullyCreatesANewAuction() public {
        // bid should create a new auction when called
        vm.prank(ALICE);
        miyaTees.bidTees(1);
    }

    function testRevert_NotOwnerCantWithdrawETH() public {
        // try withdrawing this
        // test should revert
        vm.prank(ALICE);
        vm.expectRevert();
        miyaTees.withdrawETH();
    }

    function testOwnerCanWithdrawETH() public prank(SELLER) {
        miyaTees.withdrawETH();
    }

    function testContractIsNotBrickedIfReceiverIsAContractThatRevertsOnReceive() public {
        // contract is not bricked if the last bidder happens to be a contract that reverts on receive
        BadReceiver bad;
        bad = new BadReceiver(payable(address(miyaTees)));
        deal(address(bad), type(uint256).max);

        bad.attack{value: 1 ether}(1337);
        // bad.attack{value: type(uint8).max}(12);
        // do sum mo
    }

    function notOwnerCannotSetReservePrice() public {
        // only owner can call this function
        vm.prank(ALICE);
        miyaTees.setReservePrice(type(uint8).min);
    }

    function auctionDurationCanNotBeSetToZero() public {
        // internal check works as expected
        // internal price can not be set to zero
        vm.prank(SELLER);
        miyaTees.setDuration(type(uint8).min);
    }

    function ReservePriceCannotBeSetToZero() public {
        // internal price can not be set to zero
        vm.prank(SELLER);
        miyaTees.setReservePrice(type(uint8).min);
    }

    function ReservePercentageCannotBeSetToZero() public {
        // internal price can not be set to zero
        vm.prank(SELLER);
        miyaTees.setReservePercentage(type(uint8).min);
    }

    function OnlyOwnerCanSetBidIncrement() public {
        // owner can set this value
        // owner can set duration
        vm.prank(SELLER);
        miyaTees.setDuration(type(uint32).max);

        console2.log("new end time: ", miyaTees.auctionData().endTime);
    }

    function OnlyOwnerCanSetDuration() public {
        // owner can set duration
        vm.prank(SELLER);
        miyaTees.setDuration(type(uint32).max);

        console2.log("new end time: ", miyaTees.auctionData().endTime);
    }

    function OnlyOwnerCanSetReservePercentage() public {
        // owner can set this value alone
    }

    function settleAuctionSendsTheNFTCorrectly() public {
        // auction should send the NFTs to the bid winner after the
        // timer has passed
        vm.prank(ALICE);
    }

    function testReturnOwner() public {
        // owner can set this value alone
        vm.prank(BOB);
        miyaTees.owner();
    }

    function testReturnNFT() public {
        // owner can set this value alone
        vm.prank(BOB);
        miyaTees.nft();
    }

    function testReturnBidIncrement() public {
        // owner can set this value alone
        vm.prank(BOB);
        miyaTees.BID_INCREMENT();
    }

    function testReturnAuctionDuration() public {
        // owner can set this value alone
        vm.prank(BOB);
        miyaTees.AUCTION_DURATION();
    }

    function testCheckIfAuctionHasEnded() public {
        // owner can set this value alone
        vm.prank(BOB);
        (bool s) = miyaTees.hasEnded();
        console2.log("response: ", s);
    }
}
