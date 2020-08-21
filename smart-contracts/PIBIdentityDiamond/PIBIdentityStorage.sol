pragma solidity 0.5.0;

import "../PIBController.sol";

contract PIBIdentityStorage {
    
    PIBController controller;
    
    uint public version;
    uint public state;
    string public name; //Nickname for Name Service 
    address public wallet; //Address of the current wallet 
    address public owner; //EOA owner of the contract 
    address public recovery; //EOA used for recovery of the ownership
    uint public minBalance; //Min balance allowed for EOAs 
    uint public rechargeAmount; //Amount to recharge for EOA
    //DIAMOND
    uint public facetCategory;
    //FUTURE
    uint public future1;
    uint public future2;
    address public future3;
    address public future4;
    bool public future5;
    bytes32 public future6;

    mapping(address => uint) public kinds; //contract_address:kind
    mapping(bytes32 => uint) public future7;
    mapping(uint => bytes32) public future8;
}