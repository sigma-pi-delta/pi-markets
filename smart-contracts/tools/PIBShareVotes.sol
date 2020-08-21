pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../PIBRegistry.sol";
import "../PIBIdentityDiamond/PIBIdentityInterface.sol";
import "../tokens/utils/packable/PNFTInterface.sol";
import "../tokens/utils/packable/PNFTokenReceiver.sol";

contract PIBShareVotes is PNFTokenReceiver {
    using SafeMath for uint;

    PIBController public controller;
    uint public index;
    address public tokenAddress;
    bytes32 public tokenId;
    address payable [] public users;
    mapping(address => bool) public isUser;

    event Pay(address to, uint amount, uint index);

    constructor(address _controller) public {
        controller = PIBController(_controller);
    }

    function onPNFTReceived(
        address _operator,
        address _from,
        bytes32 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external
        returns(bytes4)
    {
        return bytes4(keccak256("onPNFTReceived(address,address,bytes32,uint256,bytes)"));
    }

    function getUsers() public view returns(address payable[] memory){
        return users;
    }

    function getUserCounter() public view returns(uint) {
        return users.length;
    }

    function withdrawl(address _tokenAddress, uint _amount) public {
        require(msg.sender == controller.backend());
        bytes memory empty;
        PNFTInterface _token = PNFTInterface(_tokenAddress);
        _token.safeTransferFrom(address(this), msg.sender, tokenId, _amount, empty);
    }

    function setToken(address _tokenAddress) public {
        require(msg.sender == controller.backend());
        tokenAddress = _tokenAddress;
    }

    function setTokenId(bytes32 _tokenId) public {
        require(msg.sender == controller.backend());
        tokenId = _tokenId;
    }

    function setNewUsersArray(address payable[] memory _users) public {
        for (uint i = 0; i < _users.length; i++) {
            setNewUser(_users[i]);
        }
    }

    function isAllowed(address payable _user) public view returns (bool) {
        PIBRegistry _registry = PIBRegistry(address(uint160(controller.addresses(1))));
        
        if (msg.sender != controller.backend()) {
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

        while((gasleft() > 100000) && (index < users.length)) {
            _payUser(users[index]);
            index++;
        }

        if (index >= users.length) {
            index = 0;
        }
    }

    function payN(uint _n) public {
        for (uint i = 0; i < _n; i++) {
            _payUser(users[i.add(index)]);
            index++;
        }

        if (index >= users.length) {
            index = 0;
        }
    }

    function _payUser(address payable _user) private {
        uint _amount = 1 ether;

        bytes memory empty;
        PNFTInterface _token = PNFTInterface(tokenAddress);
        _token.safeTransferFrom(address(this), _user, tokenId, _amount, empty);

        emit Pay(_user, _amount, index);
    }
}