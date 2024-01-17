
pragma solidity 0.8.0;

contract bidTeestsol {
    modifier whenNoAuctionExists() {
        _;
    }

    function test_RevertGiven_MsgsenderIsAContract() external whenNoAuctionExists {
        // it should revert
    }

    function test_GivenMsgsenderIsAnEOA() external whenNoAuctionExists {
        // it should create a new auction, with default values
    }

    modifier givenAnAuctionExists() {
        _;
    }

    function test_GivenCurrentMsgsenderBidsHigher() external givenAnAuctionExists {
        // it should refund the previous msgsender a bit less than was sent in
    }
}
