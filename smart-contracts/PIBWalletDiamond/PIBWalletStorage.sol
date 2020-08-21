pragma solidity 0.5.0;

import "../PIBController.sol";

contract PIBWalletStorage {
    PIBController public controller;
    
    mapping(address => uint) public maxValues; //token:max_tx_value
    mapping(address => bool) public allowedReceiver; //receiver:isAllowed
    mapping(address => bool) public isToken;
    mapping(address => bool) public isNFToken;
    mapping(address => bool) public isValueLimited; //current_state (is To limited or not)
    mapping(address => bool) public isDayLimited; //current_state (is To limited or not)
    mapping(address => uint) public dayLimits;
    mapping(address => uint) public daySpent;
    mapping(address => uint) public dayByToken;
    mapping(bytes32 => uint) public future7;
    mapping(uint => bytes32) public future8;
    
    uint8 public version;
    address public owner;
    bool public isToLimited; //current_state (is Value limited or not)
    address[] public tokens;
    address[] public nfts;

    //DIAMOND
    uint public facetCategory;

    //FUTURE
    uint public future1;
    uint public future2;
    address public future3;
    address public future4;
    bool public future5;
    bytes32 public future6;
}