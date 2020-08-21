pragma solidity ^0.5.0;

contract Helper {

    uint public x;

    event ReceiveCall(address sender, uint value, uint arg);

    constructor() public {

    }

    function calledPi(uint _arg) external payable returns (uint) {
        x = _arg;

        emit ReceiveCall(msg.sender, msg.value, x);

        return x;
    }

    function factoryCall() public view returns(address) {
        return address(this);
    }
}