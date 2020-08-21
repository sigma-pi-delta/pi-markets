pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../PIBRegistry.sol";
import "../PIBIdentityDiamond/PIBIdentityInterface.sol";

contract PIBPayCommission {
    using SafeMath for uint;

    PIBController public controller;
    bool public isPaying;
    uint public index;
    uint public amount;
    uint public counter;
    address payable [] public users;
    mapping(address => bool) public isUser;

    event Pay(address to, uint amount, uint index);

    constructor(address _controller) public {
        controller = PIBController(_controller);
    }

    function () external payable {
        require(!isPaying);
        isPaying = true;
        amount = address(this).balance;
    }

    function getUsers() public view returns(address payable[] memory){
        return users;
    }

    function getUserCounter() public view returns(uint) {
        return users.length;
    }

    function withdrawl() public {
        require(msg.sender == controller.backend());
        msg.sender.transfer(address(this).balance);
    }

    function toggleIsPaying() public {
        require(msg.sender == controller.backend());
        isPaying = !isPaying;
    }

    function setNewUsersArray(address payable[] memory _users) public {
        for (uint i = 0; i < _users.length; i++) {
            setNewUser(_users[i]);
        }
    }

    function isAllowed(address payable _user) public view returns (bool) {
        PIBRegistry _registry = PIBRegistry(address(uint160(controller.addresses(1))));
        
        if ((msg.sender != controller.backend()) && (msg.sender != controller.addresses(17))) {
            return false;
        } else if (isPaying) {
            return false;
        } else if (isUser[_user]) {
            return false;
        } else if (_registry.hashesDD(_user) == bytes32(0)) {
            return false;
        }

        return true;
    }

    function setNewUser(address payable _user) public {
        require(isAllowed(_user));
        PIBIdentityInterface _identity = PIBIdentityInterface(_user);
        address payable _wallet = address(uint160(_identity.wallet()));
        isUser[_user] = true;
        users.push(_wallet);
    }

    function pay() public {
        require(isPaying);

        while((gasleft() > 100000) && (index < users.length)) {
            _payUser(users[index]);
            index++;
        }

        if (index >= users.length) {
            index = 0;
            isPaying = false;
            amount = 0;
        }
    }

    function _payUser(address payable _user) private{
        uint _amount = amount.div(users.length);
        _user.transfer(_amount);
        counter = counter.add(_amount);
        emit Pay(_user, _amount, index);
    }
}