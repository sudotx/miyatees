// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address, address, uint256) external;
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
    error AuctionEnded();
    error AuctionNotStartedYet();
    error AuctionAlreadyStarted();
    error ZeroAddress();

    event RefundPaid();
    event BidPlaced(address indexed sender, uint256 amount);
    event AuctionStarted();
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            PRICING PARAMS
    //////////////////////////////////////////////////////////////*/
    IERC721 public nft;
    uint256 public nftId;
    address payable public seller;
    uint256 public endAt;
    bool public started;
    bool public ended;
    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public pendingReturns;

    constructor(address payable _beneficiary, address _nft, uint256 _nftId) {
        if (_beneficiary == address(0)) {
            revert ZeroAddress();
        }
        if (_nft == address(0)) {
            revert ZeroAddress();
        }
        nft = IERC721(_nft);
        nftId = _nftId;
        seller = payable(_beneficiary);
    }

    function startAuction() external onlyOwner {
        if (!started) {
            revert AuctionAlreadyStarted();
        }

        started = true;
        endAt = block.timestamp + 3 days;

        nft.transferFrom(msg.sender, address(this), nftId);

        emit AuctionStarted();
    }

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGOORS
    //////////////////////////////////////////////////////////////*/
    function bidTees() public payable {
        if (!started) {
            revert AuctionNotStartedYet();
        }

        if (block.timestamp > endAt) {
            revert AuctionEnded();
        }

        if (msg.value < highestBid) {
            revert InsufficientFundsSent();
        }

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    /**
     * @dev Users can claim a refund
     */
    function withdrawPendingReturns() external {
        uint256 bal = pendingReturns[msg.sender];
        if (bal > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(bal);
        }
        emit Withdraw(msg.sender, bal);
    }

    function endAuction() external onlyOwner {
        if (!started) {
            revert AuctionNotStartedYet();
        }

        if (block.timestamp < endAt) {
            revert AuctionNotOver();
        }

        if (ended) {
            revert AuctionEnded();
        }

        ended = true;
        if (highestBidder != address(0)) {
            // Assumption: the safe transfer functionality cannot be bricked since it is dealing with just one token.
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            (bool success,) = seller.call{value: highestBid}("");
            if (!success) {
                revert WithdrawFailed();
            }
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
