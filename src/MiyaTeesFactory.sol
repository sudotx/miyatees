// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Bytes32AddressLib} from "@solmate/utils/Bytes32AddressLib.sol";
import {MiyaTeesAuction} from "@src/MiyaTees.sol";

contract MiyaTeeAuctionFactory {
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    uint256 poolNumber;

    event AuctionDeployed(uint256 indexed id, MiyaTeesAuction indexed auction, address indexed deployer);

    constructor() {}

    function deployAuction() public returns (MiyaTeesAuction auction, uint256 index) {
        // calculate pool id
        unchecked {
            index = ++poolNumber;
        }

        // deploy auction contract
        //? explore deploying using clones
        auction = new MiyaTeesAuction{salt: bytes32(index)}(payable(address(1)), address(2), 1, 1, 1);

        // emit event
        emit AuctionDeployed(index, auction, msg.sender);
    }

    function getAuctionFromNumber(uint256 id) external view returns (MiyaTeesAuction auction) {
        // retreive auction
        return MiyaTeesAuction(
            payable(
                keccak256(
                    abi.encodePacked(
                        bytes1(0xFF),
                        address(this),
                        bytes32(id),
                        keccak256(abi.encodePacked(type(MiyaTeesAuction).creationCode))
                    )
                ).fromLast20Bytes()
            )
        );
    }
}
