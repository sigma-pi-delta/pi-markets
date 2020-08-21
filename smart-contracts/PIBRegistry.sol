pragma solidity 0.5.0;

import "./PIBController.sol";
import "./PIBIdentityDiamond/PIBIdentityInterface.sol";
import "./safeMath.sol";

/// @title Registry Contract of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Registers relation between user data and it's identity
/// @dev Bidirectional mapping of Hash(user_data) and identity_contract_address

contract PIBRegistry {
    using SafeMath for uint;

    PIBController public controller;
    bool public on;
    uint public walletAmount;
    uint public ownerAmount;
    uint public recoveryAmount;
    
    mapping(bytes32 => address) public identities;
    mapping(address => bytes32) public hashes;
    mapping(bytes32 => address) public identitiesDD; //data with Due Diligence
    mapping(address => bytes32) public hashesDD; //data with Due Diligence
    
    event NewIdentity(address indexed identity, bytes32 indexed _dataHash);
    event NewIdentityDD(address indexed identity, bytes32 indexed _dataHashDD);
    
    modifier isOn {
        require(on, "012");
        _;
    }
    
    constructor(address _controllerAddress) public {
        on = true;
        walletAmount = 900000000000000000; //0.9 
        ownerAmount = 50000000000000000; //0.05
        recoveryAmount = 50000000000000000; //0.05
        controller = PIBController(_controllerAddress);
    }

    function () external payable {

    }

    function withdrawl(uint _value) public isOn {
        require(msg.sender == controller.owner(), "013"); //controller.owner
        msg.sender.transfer(_value);
    }

    function changeAmounts(uint _walletAmount, uint _ownerAmount, uint _recoveryAmount) public isOn {
        require(msg.sender == controller.owner(), "014"); //controller.owner
        walletAmount = _walletAmount;
        ownerAmount = _ownerAmount;
        recoveryAmount = _recoveryAmount;
    }
    
    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() external {
        require(msg.sender == controller.switcher(), "015");
        on = !on;
    }
    
    /// @notice New registry 
    /// @dev Set mappings for HASH:PIBID 
    /// @param _identity Address of Identity contract 
    /// @param _dataHash Hash of user's data 
    function setNewIdentity(address _identity, bytes32 _dataHash) external isOn {
        require(msg.sender == controller.addresses(2), "016"); //PIBIdentityFactory
        require(isHashAvailable(_dataHash), "017");
        require(hashes[_identity] == bytes32(0), "018");
        
        identities[_dataHash] = _identity;
        hashes[_identity] = _dataHash;
        
        emit NewIdentity(_identity, _dataHash);
    }

    function setNewIdentityDD(address _identity, bytes32 _dataHashDD) external isOn {
        require(msg.sender == controller.backend(), "019"); //controller.backend
        require(hashes[_identity] != bytes32(0), "020"); //identity exists
        require(hashesDD[_identity] == bytes32(0), "021"); //identityDD doesn't have hash
        require(identitiesDD[_dataHashDD] == address(0), "022"); //hash was never used before
        
        identitiesDD[_dataHashDD] = _identity;
        hashesDD[_identity] = _dataHashDD;

        _transferPromotional(_identity);
        
        emit NewIdentityDD(_identity, _dataHashDD);
    }
    
    function isHashAvailable(bytes32 _dataHash) public view returns (bool) {
        return identities[_dataHash] == address(0);
    }

    function _transferPromotional(address _identity) private {
        if (address(this).balance >= walletAmount.add(ownerAmount).add(recoveryAmount)) {
            PIBIdentityInterface _identityContract = PIBIdentityInterface(_identity);
            address payable _wallet = address(uint160(_identityContract.wallet()));
            address payable _owner =  address(uint160(_identityContract.owner()));
            address payable _recovery =  address(uint160(_identityContract.recovery()));

            _wallet.transfer(walletAmount);
            _owner.transfer(ownerAmount);
            _recovery.transfer(recoveryAmount);
        }
    }

}