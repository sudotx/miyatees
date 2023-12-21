// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {ERC721TokenReceiver, ERC721} from "@solmate/tokens/ERC721.sol";

contract MiyaTees is ReentrancyGuard, ERC721TokenReceiver {
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
    ERC721 public immutable nft;
    mapping(address => uint256) public refunds;

    uint256 public constant AUCTION_DURATION = 3 days;
    uint256 public constant BID_INCREMENT = 0.05 ether;

    constructor(address payable _beneficiary, address _nft, uint256 _nftId) {
        if (_beneficiary == address(0)) {
            revert ZeroAddress();
        }
        if (_nft == address(0)) {
            revert ZeroAddress();
        }
        nft = ERC721(_nft);
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
            refunds[msg.sender] += msg.value;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    /**
     * @dev Users can claim a refund
     */
    function withdrawPendingReturns() external nonReentrant {
        uint256 bal = refunds[msg.sender];
        refunds[msg.sender] = 0;
        emit Withdraw(msg.sender, bal);
        SafeTransferLib.safeTransferETH(msg.sender, bal); 
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
        if (highestBidder != address(0)) {
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            SafeTransferLib.safeTransferETH(seller, address(this).balance);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }

    // allows the contract receive 721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
