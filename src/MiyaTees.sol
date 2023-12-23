// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "@solady/auth/Ownable.sol";
import {Receiver} from "@solady/accounts/Receiver.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract MiyaTeesAuction is Receiver, Ownable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error InsufficientETHSent();
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
    event End(address winner, uint256 amount);
    event AuctionSettled(uint256 indexed nftId, address winner, uint256 amount);
    event AuctionDurationUpdated(uint256 amount);
    event AuctionBidIncrementUpdated(uint256 amount);

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionReservePercentageUpdated(uint256 reservePercentage);

    /*//////////////////////////////////////////////////////////////
                            PRICING PARAMS
    //////////////////////////////////////////////////////////////*/

    struct AuctionData {
        address bidder;
        uint96 amount;
        uint40 startTime;
        uint40 endTime;
        uint96 withdrawable;
        bool settled;
        address miyaTees;
        uint8 reservePercentage;
        uint96 reservePrice;
        uint96 bidIncrement;
        uint32 duration;
        uint32 timeBuffer;
    }

    AuctionData internal _auctionData;

    uint256 public endAt;
    bool public started;
    bool public ended;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public immutable nftId;
    address payable public immutable seller;
    IERC721 public immutable nft;
    mapping(address => uint256) public refunds;

    uint32 public constant AUCTION_DURATION = 3 days;
    uint96 public constant BID_INCREMENT = 0.05 ether;

    constructor(
        address payable _beneficiary,
        address _miyaTees,
        uint256 _nftId,
        uint96 reservePrice,
        uint32 timeBuffer,
        uint8 reservePercentage
    ) payable {
        if (_beneficiary == address(0)) {
            revert ZeroAddress();
        }
        if (_miyaTees == address(0)) {
            revert ZeroAddress();
        }

        _auctionData.duration = AUCTION_DURATION;
        _auctionData.bidIncrement = BID_INCREMENT;
        _auctionData.miyaTees = _miyaTees;
        _auctionData.timeBuffer = timeBuffer;
        _auctionData.reservePrice = reservePrice;
        _auctionData.reservePercentage = reservePercentage;

        nft = IERC721(_miyaTees);
        nftId = _nftId;
        seller = payable(_beneficiary);

        nft.transferFrom(msg.sender, address(this), nftId);
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC/EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function hasEnded() public view returns (bool) {
        // fix this
        return block.timestamp >= AUCTION_DURATION;
    }

    function auctionData() public view returns (AuctionData memory data) {
        data = _auctionData;
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC/EXTERNAL WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function bidTees() external payable {
        require(gasleft() > 150000);

        // auto auction creation and settlement

        bool creationFailed;
        if (_auctionData.startTime == 0) {
            // if auction not created
            // create a new auction
            creationFailed = !_createAuction();
        } else if (hasEnded()) {
            // if auction has ended, and is settled. try creating a new one
            if (_auctionData.settled) {
                creationFailed = !_createAuction();
            } else {
                // if auction has ended, but not settled. settle it
                _settleAuction();
                // try creating new one, after settling previous
                if (!_createAuction()) {
                    // if creation failed refund all ETH sent
                    SafeTransferLib.forceSafeTransferETH(msg.sender, msg.value);
                    return;
                }
            }
        }

        require(!creationFailed, "cannot create auction");

        // bidding logic

        address lastBidder = _auctionData.bidder;
        uint256 amount = _auctionData.amount;
        uint256 endTime = _auctionData.endTime;

        if (amount == 0) {
            require(msg.value > _auctionData.reservePrice, "bid below reserve price");
        } else {
            require(msg.value > amount + _auctionData.bidIncrement);
        }

        _auctionData.bidder = msg.sender;
        _auctionData.amount = SafeCastLib.toUint96(msg.value);

        if (_auctionData.timeBuffer == 0) {
            // emit auction bid
            // emit AuctionBid(bonklerId, msg.sender, msg.value, false);
            emit BidPlaced(msg.sender, msg.value);
        } else {
            // Extend the auction if the bid was received within `timeBuffer` of the auction end time.
            uint256 extendedTime = block.timestamp + _auctionData.timeBuffer;
            // Whether the current timestamp falls within the time extension buffer period.
            bool extended = endTime < extendedTime;
            // emit AuctionBid(bonklerId, msg.sender, msg.value, extended);
            emit BidPlaced(msg.sender, msg.value);

            if (extended) {
                _auctionData.endTime = SafeCastLib.toUint40(extendedTime);
                // emit AuctionExtended(bonklerId, extendedTime);
            }
        }

        if (amount != 0) {
            // refund last bidder
            SafeTransferLib.forceSafeTransferETH(lastBidder, amount);
        }
    }

    function settleAuction() external {
        require(block.timestamp > endAt);
        require(started);
        require(!ended);
        // require(block.timestamp >= _auctionData.endTime);
        require(_auctionData.startTime != 0);
        require(_auctionData.bidder != address(0));
        require(!_auctionData.settled);
        _settleAuction();
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function withdrawETH() external onlyOwner {
        uint256 amount = _auctionData.withdrawable;
        _auctionData.withdrawable = 0;
        SafeTransferLib.forceSafeTransferETH(msg.sender, amount);
    }

    function setReservePrice(uint8 reservePercentage) external onlyOwner {
        _checkReservePercentage(reservePercentage);
        _auctionData.reservePercentage = reservePercentage;
        emit AuctionReservePriceUpdated(reservePercentage);
    }

    function setBidIncrement(uint96 bidIncrement) external onlyOwner {
        _checkBidIncrement(bidIncrement);
        _auctionData.bidIncrement = bidIncrement;
        emit AuctionBidIncrementUpdated(bidIncrement);
    }

    function setDuration(uint32 duration) external onlyOwner {
        _checkDuration(duration);
        _auctionData.duration = duration;
        emit AuctionDurationUpdated(duration);
    }

    function setTimeBuffer(uint32 timeBuffer) external onlyOwner {
        _auctionData.timeBuffer = timeBuffer;
        emit AuctionTimeBufferUpdated(timeBuffer);
    }

    function setReservePercentage(uint8 reservePercentage) external onlyOwner {
        _checkReservePercentage(reservePercentage);
        _auctionData.reservePercentage = reservePercentage;
        emit AuctionReservePercentageUpdated(reservePercentage);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL/PRIVATE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createAuction() internal returns (bool) {
        uint256 endT = block.timestamp + AUCTION_DURATION;

        _auctionData.bidder = address(1);
        _auctionData.amount = 0;
        _auctionData.startTime = SafeCastLib.toUint40(block.timestamp);
        _auctionData.endTime = SafeCastLib.toUint40(endT);
        _auctionData.settled = false;

        emit AuctionStarted(endT);

        return true;
    }

    function _settleAuction() internal {
        address bidder = _auctionData.bidder;
        uint256 amount = _auctionData.amount;
        uint256 withdrawable = _auctionData.withdrawable;
        uint256 reservePercentage = _auctionData.reservePercentage;
        address miyaTees = _auctionData.miyaTees;

        uint256 miyaShares = amount * reservePercentage / 100;
        withdrawable += amount - miyaShares;

        IERC721(miyaTees).transferFrom(address(this), bidder, nftId);

        _auctionData.settled = true;
        _auctionData.withdrawable = SafeCastLib.toUint96(withdrawable);

        emit AuctionSettled(nftId, bidder, amount);
    }

    function _checkReservePercentage(uint8 reservePercentage) internal pure {
        require(reservePercentage < 101, "reserve % exceeds 100");
    }

    function _checkReservePrice(uint96 reservePrice) internal pure {
        require(reservePrice != 0, "reserve price must be greater than 0");
    }

    function _checkBidIncrement(uint96 bidIncrement) internal pure {
        require(bidIncrement != 0, "bid increment must be greater than 0");
    }

    function _checkDuration(uint32 duration) internal pure {
        require(duration != 0, "duration must be greater than 0");
    }
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 id) external;
    function transferFrom(address from, address to, uint256 id) external;
}
