// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Receiver} from "@solady/accounts/Receiver.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

/**
 *   88b           d88  88                      888888888888
 *   888b         d888  ""                           88
 *   88`8b       d8'88                               88
 *   88 `8b     d8' 88  88  8b       d8  ,adPPYYba,  88   ,adPPYba,   ,adPPYba,  ,adPPYba,
 *   88  `8b   d8'  88  88  `8b     d8'  ""     `Y8  88  a8P_____88  a8P_____88  I8[    ""
 *   88   `8b d8'   88  88   `8b   d8'   ,adPPPPP88  88  8PP"""""""  8PP"""""""   `"Y8ba,
 *   88    `888'    88  88    `8b,d8'    88,    ,88  88  "8b,   ,aa  "8b,   ,aa  aa    ]8I
 *   88     `8'     88  88      Y88'     `"8bbdP"Y8  88   `"Ybbd8"'   `"Ybbd8"'  `"YbbdP"'
 *                           d8'
 *                          d8'
 */
// forgefmt: disable-end

contract MiyaTeesAuction is Receiver {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error BidBelowReservePrice();
    error BidBelowCurrentBidIncrement();
    error CannotCreateAuction();
    error ZeroAddress();
    error NotOwner();

    /*//////////////////////////////////////////////////////////////
                            AUCTION PARAMS
    //////////////////////////////////////////////////////////////*/

    struct AuctionData {
        address bidder;
        uint256 miyaTeeId;
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
    }

    AuctionData internal _auctionData;
    address payable public immutable seller;
    address public immutable owner;
    IERC721 public immutable nft;
    uint32 public constant AUCTION_DURATION = 3 days;
    uint96 public constant BID_INCREMENT = 0.05 ether;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BidPlaced(uint256 indexed nftId, address indexed sender, uint256 amount);
    event AuctionStarted(uint256 endTime);
    event AuctionSettled(uint256 indexed nftId, address winner, uint256 amount);
    event AuctionDurationUpdated(uint256 amount);
    event AuctionBidIncrementUpdated(uint256 amount);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionReservePercentageUpdated(uint256 reservePercentage);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor(
        address payable _beneficiary,
        address _miyaTees,
        uint256 _nftId,
        uint96 reservePrice,
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
        _auctionData.reservePrice = reservePrice;
        _auctionData.reservePercentage = reservePercentage;
        _auctionData.miyaTeeId = _nftId;

        owner = msg.sender;
        seller = payable(_beneficiary);
        nft = IERC721(_miyaTees);
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC/EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice This will check if an auction is still running
     */
    function hasEnded() public view returns (bool) {
        return block.timestamp >= _auctionData.duration;
    }

    /*
     * @notice This returns the current auction associated data
     */
    function auctionData() public view returns (AuctionData memory data) {
        data = _auctionData;
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC/EXTERNAL WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice This allows users to bid on tees
     *  it automatically creates an auction if one is not running at the moment, with default data
     * also settles an outstanding auction, lastly it refunds the previous bidder its deposited eth
     * bid has to be above reserve price + bid increment in the case where the user is not the first to bid on the item
     * extends the time for the auction if a bid comes in within the auctions time buffer
     */
    function bidTees(uint256 id) external payable {
        require(gasleft() > 150000);

        // auto auction creation and settlement

        bool creationFailed;
        //! need to go over this bit more, to make sure it works as intended
        if (_auctionData.startTime == 0) {
            // if auction not created
            // create a new auction
            creationFailed = !_createAuction(id);
        } else if (hasEnded()) {
            // if auction has ended, and is settled. try creating a new one
            if (_auctionData.settled) {
                creationFailed = !_createAuction(id);
            } else {
                // if auction has ended, but not settled. settle it
                _settleAuction();
                // try creating new one, after settling previous
                if (!_createAuction(id)) {
                    // if creation failed refund all ETH sent
                    SafeTransferLib.forceSafeTransferETH(msg.sender, msg.value);
                    return;
                }
            }
        }

        if (creationFailed) {
            revert CannotCreateAuction();
        }

        // bidding logic

        address lastBidder = _auctionData.bidder;
        uint256 amount = _auctionData.amount;

        uint256 miyaTeeId = _auctionData.miyaTeeId;

        if (amount == 0) {
            if (msg.value < _auctionData.reservePrice) {
                revert BidBelowReservePrice();
            }
        } else {
            if (msg.value < amount + _auctionData.bidIncrement) {
                revert BidBelowCurrentBidIncrement();
            }
        }

        _auctionData.bidder = msg.sender;
        _auctionData.amount = SafeCastLib.toUint96(msg.value);

        emit BidPlaced(miyaTeeId, msg.sender, msg.value);

        if (amount != 0) {
            // refund last bidder
            SafeTransferLib.forceSafeTransferETH(lastBidder, amount);
        }
    }

    /*
     * @notice This settles the current running auction
     */
    function settleAuction() external {
        require(block.timestamp > _auctionData.endTime);
        require(_auctionData.startTime != 0);
        require(_auctionData.bidder != address(0));
        require(!_auctionData.settled);
        _settleAuction();
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice This allows the admin to withdraw eth
     */
    function withdrawETH() external onlyOwner {
        uint256 amount = _auctionData.withdrawable;
        _auctionData.withdrawable = 0;
        SafeTransferLib.forceSafeTransferETH(msg.sender, amount);
    }

    /*
     * @notice This allows the admin to set the lowest possible bid price for the item
     */
    function setReservePrice(uint8 reservePrice) external onlyOwner {
        _checkReservePrice(reservePrice);
        _auctionData.reservePrice = reservePrice;
        emit AuctionReservePriceUpdated(reservePrice);
    }

    /*
     * @notice This allows the admin to set the bid increment for the auction
     */
    function setBidIncrement(uint96 bidIncrement) external onlyOwner {
        _checkBidIncrement(bidIncrement);
        _auctionData.bidIncrement = bidIncrement;
        emit AuctionBidIncrementUpdated(bidIncrement);
    }

    /*
     * @notice This allows the admin to set the duration for the auction
     */
    function setDuration(uint32 duration) external onlyOwner {
        _checkDuration(duration);
        _auctionData.duration = duration;
        emit AuctionDurationUpdated(duration);
    }

    /*
     * @notice This allows the admin to set the percentage of funds to leave in the contract on withdrawal, the max withdrawable amount 
     * depends on this value
     */

    function setReservePercentage(uint8 reservePercentage) external onlyOwner {
        _checkReservePercentage(reservePercentage);
        _auctionData.reservePercentage = reservePercentage;
        emit AuctionReservePercentageUpdated(reservePercentage);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL/PRIVATE HELPERS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice This creates a new auction
     * this assigns default values to the auction
     * ideally these will be overwritten by the actual values
     */

    function _createAuction(uint256 _nftId) internal returns (bool) {
        uint256 endTime = block.timestamp + AUCTION_DURATION;
        //! might lead to issues, test this does become problematic
        _auctionData.bidder = address(1);
        _auctionData.miyaTeeId = 0;
        _auctionData.amount = 0;
        _auctionData.startTime = SafeCastLib.toUint40(block.timestamp);
        _auctionData.endTime = SafeCastLib.toUint40(endTime);
        _auctionData.settled = false;

        nft.transferFrom(owner, address(this), _nftId);

        emit AuctionStarted(endTime);

        return true;
    }

    /*
     * @notice This settles the auction, by sending out the nft associated with the auction
     * also setting its status to true
     */

    function _settleAuction() internal {
        address bidder = _auctionData.bidder;
        uint256 amount = _auctionData.amount;
        uint256 withdrawable = _auctionData.withdrawable;
        uint256 reservePercentage = _auctionData.reservePercentage;
        address miyaTees = _auctionData.miyaTees;

        uint256 MiyaTeeId = _auctionData.miyaTeeId;

        uint256 miyaShares = amount * reservePercentage / 100;
        withdrawable += amount - miyaShares;

        _auctionData.settled = true;
        _auctionData.withdrawable = SafeCastLib.toUint96(withdrawable);

        IERC721(miyaTees).transferFrom(address(this), bidder, MiyaTeeId);

        emit AuctionSettled(MiyaTeeId, bidder, amount);
    }

    /*
     * @notice This performs sanity check on the value to be set as the reseve percentage
     * making sure it never exceeds 100%
     */

    function _checkReservePercentage(uint8 reservePercentage) internal pure {
        require(reservePercentage < 101, "reserve % exceeds 100");
    }

    /*
     * @notice This performs sanity checks on the reserve price
     * making sure it is always greater than zero
     */
    function _checkReservePrice(uint96 reservePrice) internal pure {
        require(reservePrice != 0, "reserve price must be greater than 0");
    }

    /*
     * @notice This performs sanity checks making sure it is 
     * always greater than zero
     */
    function _checkBidIncrement(uint96 bidIncrement) internal pure {
        require(bidIncrement != 0, "bid increment must be greater than 0");
    }

    /*
     * @notice This performs sanity checks making sure it is always 
     * greater than zero
     */

    function _checkDuration(uint32 duration) internal pure {
        require(duration != 0, "duration must be greater than 0");
    }
}

interface IERC721 {
    function transferFrom(address from, address to, uint256 id) external;
    function approve(address from, uint256 id) external;
}
