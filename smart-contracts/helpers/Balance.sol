pragma solidity ^0.5.0;

contract Balance {
    
    constructor() public {
        
    }
    
    function getBalance(address _address) public view returns(uint) {
        return _address.balance;
    }
    
    function f() public {
        msg.sender.transfer(address(this).balance);
    }
}