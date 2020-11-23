pragma solidity 0.5.0;

import "../PIBController.sol";

contract PIBAuctionStorage {
    struct Asset {
        address token;
        uint amountOrId;
        bytes32 tokenId; //only when packables
        uint8 category; // 1-Token, 2-NFT, 3-Packable
    }

    address payable public owner;
    address public factory;
    address public auditor;
    address public auctionToken;
    address public bidToken;
    address public maxBidder;
    uint public minValue;
    uint public endTime;
    uint public maxBid;
    uint public commission;
    bool public isOpen;
    bool public isKillable;

    PIBController public controller;
    Asset public asset;

    mapping(address => uint) public bids;
}