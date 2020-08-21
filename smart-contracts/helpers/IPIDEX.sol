pragma solidity ^0.5.0;

 /* New ERC223 contract interface */

contract IPIDEX {
    function setPiOrder(address receiving, uint price, uint side) external payable returns (bytes32);
    function setTokenOrder(address payable owner, uint amount, address receiving, uint price, uint side) public returns (bytes32);
}