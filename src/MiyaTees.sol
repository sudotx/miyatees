// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint tokenId) external;

    function transferFrom(address, address, uint) external;
}


contract MiyaTees is Ownable {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InsufficientFundsSent();
    error UnableToRefund();
    error WithdrawFailed();
    error AuctionNotOver();
    error AuctionProfitsAlreadyWithdrawn();
    error RefundFailed();
    error NotEligibleForRefund();
    error RefundAlreadyClaimed();
    error AuctionSoldOut();
    error AuctionBidExceedsMax();

    event RefundPaid();
    event BidPlaced();
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    struct AuctionBid {
        uint256 quantity;
        uint256 bid;
    }

    struct DutchAuctionConfig {
        uint256 saleStartTime;
        uint256 startPriceInWei;
        uint256 endPriceInWei;
        uint256 duration;
        uint256 dropInterval;
        uint256 MaxBidsPerAddress;
        uint256 availableTokenThatCanBeSoldDuringAuction;
        uint256 maxAmountOfBidsPerTransaction;
    }


    /*//////////////////////////////////////////////////////////////
                            PRICING PARAMS
    //////////////////////////////////////////////////////////////*/
    IERC721 public nft;
    uint public nftId;

    address payable public seller;
    uint public endAt;
    bool public started;
    bool public ended;

    address public highestBidder;
    uint public highestBid;
    mapping(address => uint) public bids;

    uint256 private startingPrice;
    uint256 private endingPrice;
    uint256 private finalPrice;
    uint256 private decrementValue;
    uint256 private decrementFrequency;
    uint256 private maxQuantity;
    uint256 internal scaleFactor;
    uint256 internal decayConstant;
    uint256 internal auctionStartTime;

    constructor(/*DutchAuctionConfig memory _config,*/ address payable _beneficiary, address _nft, uint _nftId, uint _startingBid){
        nft = IERC721(_nft);
        nftId = _nftId;

        seller = payable(_beneficiary);
        highestBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");

        nft.transferFrom(msg.sender, address(this), nftId);
        started = true;
        endAt = block.timestamp + 7 days;

        emit Start();
    }

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGOORS
    //////////////////////////////////////////////////////////////*/
    function bidTees() public payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "value < highest");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }


    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the purchase price of a number of tokens
     */
    function getPurchasePrice() public view returns (uint256) {}
    /**
     * @dev Set the dutch config. should only be accesible by owner
     */
    function setDutchConfig() public {}
    /**
     * @dev Users can claim a refund
     */
    function claimRefund(uint256 numOfTokens) public view returns (uint256) {
        // users that were outbid can claim refund here
        // since balance of all users is stored 
    }
    /**
     * @dev Owner can withdraw profits
     */
    function withdraw() public {
        uint bal = bids[msg.sender];
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            seller.transfer(highestBid);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }

    /**
     * @dev Get Bids for user
     */
    // function getBidsForUser(uint256 numOfTokens) public view returns (AuctionBid[] memory) {}
}
