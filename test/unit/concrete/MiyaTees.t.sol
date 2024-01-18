// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Test, console} from "@forge/Test.sol";
import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";

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
        console.log("setting up...");
        token = new MockERC721("MiyaTee", "MYT"); // miya tees

        vm.label(address(token), "MIYATEE");
        vm.label(address(miyaTees), "MIYATEE_AUCTION");

        token.mint(SELLER, TOKENID); // the user has to have the token, to send to the contract

        vm.startPrank(SELLER);
        miyaTees = new MiyaTeesAuction(payable(SELLER), address(token), 1337, 1, 1);
        token.approve(address(miyaTees), TOKENID);
        vm.stopPrank();

        console.log("Token Balance Of MiyaTeesAuction", token.balanceOf(address(miyaTees)));
    }

    function testAuctionContractReceivesNFTToBeBiddedOnAtAuctionStart() public {}

    function testAuctionDurationisCorrectlySet() public {}

    function testSettleAuctionCannotBeCalledIfItIsBeforeTheAuctionExpiry() public {}

    function testSettleAuctionCantBeCalledIfTheAuctionTimeIsNotZero() public {}

    function testSettleAuctionBidderIsNotTheZeroAddress() public {}

    function testSettleAuctionDataIsSettled() public {}

    function testAuctionBidIncrementisCorrectlySet() public {}

    function testAuctionMiyaTeesContractisCorrectlySet() public {}

    function testAuctionReservePriceisCorrectlySet() public {
        // critica; values should be set
    }

    function testAuctionMiyaTeeIDisCorrectlySet() public {
        // critica; values should be set
    }

    function testNFTisSentFromTheUserToThisContract() public {
        // fail if nft os not sent to the contract as expected.
    }

    function testAuctionhasEndedReturnsFalseWhenAuctionRoundIsOnGoing() public {
        // this should return false
    }

    function testAuctionhasEndedReturnsTrueWhenAuctionRoundIsEnded() public {
        // auction ended function should return correctly
    }

    function testBidTeesEndsPreviousRunningAuctionRoundCorrectly() public {
        // round should end with certain states being fufullled
    }

    function testLastBidderReceivesTheETHSuccesfulyReceivesRefund() public {
        // last bidder receives ETH set to it
    }

    function testBidSuccessfullyCreatesANewAuction() public {
        // bid should create a new auction when called
    }

    function testRevert_NotOwnerCantWithdrawETH() public {
        // try withdrawing this
        // test should revert
    }
    function testOwnerCanWithdrawETH() public prank(ALICE) {
        // owner can collect eth in the contract
    }

    function testContractIsNotBrickedIfReceiverIsAContractThatRevertsOnReceive() public {
        // contract is not bricked if the last bidder happens to be a contract that reverts on receive
    }

    function onlyOwnerCanSetReservePrice() public {
        // only owner can call this function
    }

    function auctionDurationCanNotBeSetToZero() public {
        // internal check works as expected
    }

    function ReservePriceCannotBeSetToZero() public {
        // internal price can not be set to zero
    }

    function OnlyOwnerCanSetBidIncrement() public {
        // owner can set this value
    }

    function OnlyOwnerCanSetDuration() public {
        // owner can set duration
    }

    function OnlyOwnerCanSetReservePercentage() public {
        // owner can set this value alone
    }

    function settleAuctionSendsTheNFTCorrectly() public {
        // auction should send the NFTs to the bid winner after the
        // timer has passed
    }
}
