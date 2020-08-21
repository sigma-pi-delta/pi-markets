pragma solidity ^0.5.0;

contract PIBIdentityInterface {
    address public wallet;
    address public owner; //EOA owner of the contract 
    address public recovery; //EOA used for recovery of the ownership
}