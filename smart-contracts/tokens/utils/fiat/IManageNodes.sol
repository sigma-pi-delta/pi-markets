pragma solidity ^0.5.0;

contract IManageNodes {
    function isValidator(address _node) public view returns(bool);
}