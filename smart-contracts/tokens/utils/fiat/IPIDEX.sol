pragma solidity ^0.5.0;

/// @author MIDLANTIC TECHNOLOGIES
/// @title Contract designed to handle orders in the Exchange
//0x917a8d3415f5fe494ddfb029cb0dfdfb242b6942

contract IPIDEX {
    function setTokenOrder(address payable owner, uint amount, address receiving, uint price, uint side) public returns (bytes32);
}
