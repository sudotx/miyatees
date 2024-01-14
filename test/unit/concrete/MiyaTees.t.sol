// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Test, console} from "@forge/Test.sol";
import {MiyaTeesAuction} from "@src/MiyaTees.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";
// import mocks

contract MiyaTeeTest is Test {
    event RefundPaid();
    event BidPlaced(address indexed sender, uint256 amount);
    event AuctionStarted(uint256 endTime);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    MiyaTeesAuction public miyaTees;
    MockERC721 token;

    address seller;

    function setUp() public {
        token = new MockERC721("MiyaTee", "MYT"); // miya tee

        seller = address(0x1337);
        console.log(seller);
        vm.deal(address(seller), 1 ether);

        token.mint(address(seller), 1337); // mint the token to the seller

        miyaTees = new MiyaTeesAuction(payable(address(seller)), address(token), 1337, 1, 1);

        vm.prank(address(seller));
        token.setApprovalForAll(address(miyaTees), true);
    }

    //happy paths
    function testAuctionContractCanReceiveNFT() public {}
    function testAuctionContractReceivesNFTToBeBiddedOnAtAuctionStart() public {}
    function testAuctionDurationisCorrectlySet() public {}
    function testBidTeesWorksCorrectly() public {
        //? test very well, complexity in the creation of auction if one is not currently active
        //? safe transfer eth to sender, if an auction is currently active
        //? the value that was sent to it
        //? 🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲🪲 waters 🪲🪲🪲🪲🪲
    }
    function testSettleAuctionWorksCorrectly() public {}
    function testSettleAuctionCannotBeCalledIfItIsBeforeTheAuctionExpiry() public {}
    function testSettleAuctionCantBeCalledIfTheAuctionTimeIsNotZero() public {}
    function testSettleAuctionBidderIsNotTheZeroAddress() public {}
    function testSettleAuctionDataIsSettled() public {}
    function testAuctionBidIncrementisCorrectlySet() public {}
    function testAuctionMiyaTeesContractisCorrectlySet() public {}
    function testAuctionReservePriceisCorrectlySet() public {}
    function testAuctionMiyaTeeIDisCorrectlySet() public {}
    function testNFTisSentFromTheUserToThisContract() public {}
    function testAuctionhasEndedReturnsFalseWhenAuctionRoundIsOnGoing() public {}
    function testAuctionhasEndedReturnsTrueWhenAuctionRoundIsEnded() public {}
    function testBidTeesForTheFirstTimeWorksCorrectly() public {}
    function testBidTeesEndsPreviousRunningAuctionRoundCorrectly() public {}
    function testLastBidderReceivesTheETHSuccesfulyReceivesRefund() public {}
    function testBidSuccessfullyCreatesANewAuction() public {}
    function testSettleAuctionWorksSuccesfully() public {}
    function testOnlyOwnerCanWithdrawETH() public {}
    function testContractIsNotBrickedIfReceiverIsAContractThatRevertsOnReceive() public {}
    function onlyOwnerCanSetReservePrice() public {}
    function auctionDurationCanNotBeSetToZero() public {}
    function ReservePriceCannotBeSetToZero() public {}
    function OnlyOwnerCanSetBidIncrement() public {}
    function OnlyOwnerCanSetDuration() public {}
    function OnlyOwnerCanSetReservePercentage() public {}
    function settleAuctionSendsTheNFTCorrectly() public {}
}
