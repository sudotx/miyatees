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

    /*  
    *   bidder: for a current auction, this changes based on the amount
    *   miyaTeeId: the token id under auction
    *   amount 
    *   withdrawable: available withdrawable eth
    *   settled: has auction been settled
    *   endTime: end of auction
    *   startTime: start time of auction
    *   reservePercentage: percentage of eth to be left behind
    *   reservePrice: auction base price
    *   bidIncrement: amount the bid price increases in between bids
    *   miyaTees: token contract
    */
    struct AuctionData {
        address bidder;
        uint256 miyaTeeId;
        uint96 amount;
        uint96 withdrawable;
        bool settled;
        uint40 endTime;
        uint40 startTime;
        uint8 reservePercentage;
        uint96 reservePrice;
        uint96 bidIncrement;
        address miyaTees;
    }

    AuctionData internal _auctionData;

    // seller is the primary beneficiary of this contract
    address payable public immutable seller;
    // seller can be different from seller, and is the account that deploys this contract
    address public immutable owner;
    // glorious miyatees collection
    IERC721 public immutable nft;
    // auction duration for all auctions is 3 days
    uint32 public constant AUCTION_DURATION = 3 days;

    // increase in bid price between consecutive bids
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
        /*
        *   important auction data
        */
        _auctionData.bidIncrement = BID_INCREMENT;
        _auctionData.miyaTees = _miyaTees;
        _auctionData.reservePrice = reservePrice;
        _auctionData.reservePercentage = reservePercentage;
        _auctionData.miyaTeeId = _nftId;

        owner = msg.sender;
        seller = payable(_beneficiary);
        nft = IERC721(_miyaTees);

        /**
         * sets the auction contract as controller of all tokens, owned by deployer
         * this pattern is to allow contract send token from deployer once an auction is about to be
         * created.
         */
        nft.setApprovalForAll(address(this), true);
    }

    /*//////////////////////////////////////////////////////////////
                    PUBLIC/EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice This will check if an auction is still running
     */

    function hasEnded() public view returns (bool) {
        if (block.timestamp >= _auctionData.endTime) {
            return true;
        } else {
            return false;
        }
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
        bool creationFailed;
        // if auction not created
        if (_auctionData.startTime == 0) {
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
                if (!creationFailed) {
                    // if (!_createAuction(id)) {
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
        _auctionData.endTime = duration;
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
     * 
     */

    function _createAuction(uint256 _nftId) internal returns (bool) {
        // this sets the current end of auction time to the current blocktimestmp plus the constant auction duration time
        uint256 endTime = block.timestamp + AUCTION_DURATION;
        _auctionData.bidder = msg.sender;
        _auctionData.miyaTeeId = _nftId;
        _auctionData.amount = uint96(msg.value);
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
    function setApprovalForAll(address operator, bool approved) external;
}
