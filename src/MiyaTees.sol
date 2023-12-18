// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address, address, uint256) external;
}

contract MiyaTees is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InsufficientETHSent();
    error WithdrawFailed();
    error AuctionNotOver();
    error AuctionEnded();
    error AuctionNotStartedYet();
    error AuctionAlreadyStarted();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event RefundPaid();
    event BidPlaced(address indexed sender, uint256 amount);
    event AuctionStarted(uint256 endTime);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address winner, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            PRICING PARAMS
    //////////////////////////////////////////////////////////////*/
    uint256 public endAt;
    bool public started;
    bool public ended;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public immutable nftId;
    address payable public immutable seller;
    IERC721 public immutable nft;
    mapping(address => uint256) public pendingReturns;

    uint256 public constant AUCTION_DURATION = 3 days;
    uint256 public constant BID_INCREMENT = 0.05 ether;

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

    function startAuction() external {
        if (started) {
            revert AuctionAlreadyStarted();
        }

        started = true;
        endAt = block.timestamp + AUCTION_DURATION;

        nft.transferFrom(msg.sender, address(this), nftId);

        emit AuctionStarted(endAt);
    }

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGOORS
    //////////////////////////////////////////////////////////////*/
    function bidTees() public payable {
        if (!started) {
            revert AuctionNotStartedYet();
        }
        if (ended) {
            revert AuctionEnded();
        }

        if (block.timestamp > endAt) {
            revert AuctionEnded();
        }

        if (msg.value < highestBid + BID_INCREMENT) {
            revert InsufficientETHSent();
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
    function withdrawPendingReturns() external nonReentrant {
        uint256 bal = pendingReturns[msg.sender];
        if (bal > 0) {
            pendingReturns[msg.sender] = 0;
            emit RefundPaid();
            SafeTransferLib.safeTransferETH(msg.sender, bal);
        }
        emit Withdraw(msg.sender, bal);
    }

    /**
     * @dev End the auction
     */
    function endAuction() external nonReentrant {
        if (block.timestamp > endAt) {
            revert AuctionNotOver();
        }
        if (!started) {
            revert AuctionNotStartedYet();
        }

        if (ended) {
            revert AuctionEnded();
        }

        ended = true;
        // 🪲
        if (highestBidder != address(0)) {
            // this line buggy still.. will test till works
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            SafeTransferLib.safeTransferETH(seller, address(this).balance);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
