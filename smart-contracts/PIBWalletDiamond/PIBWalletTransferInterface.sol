pragma solidity ^0.5.0;

contract PIBWalletTransferInterface {
    function transfer(
        address _tokenAddress, 
        address payable _to, 
        uint _value, 
        string memory _data,
        uint _kind
    ) 
        public;
}