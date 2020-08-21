pragma solidity 0.5.0;

import "./PIBController.sol";
import "./PIBIdentityDiamond/PIBIdentityDiamond.sol";
import "./PIBRegistry.sol";
import "./PIBWalletFactory.sol";
import "./PIBNameService.sol";

/// @title Contract to deploy identities of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Creates new identities
/// @dev Designed to deploy contracts of an identity 

contract PIBIdentityFactory {
    PIBController public controller;
    bool public on;
    
    modifier isOn {
        require(on, "008");
        _;
    }
    
    modifier onlyBackend {
        require(msg.sender == controller.backend(), "009");
        _;
    }
    
    event DeployIdentity(address indexed identity, 
        address indexed owner, 
        address recovery, 
        address indexed wallet, 
        string name, 
        bytes32 dataHash
    );
    
    constructor(address _controllerAddress) public {
        on = true;
        controller = PIBController(_controllerAddress);
    }
    
    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() external {
        require(msg.sender == controller.switcher(), "010");
        on = !on;
    }
    
    /// @notice Deploy a new Identity Contract 
    /// @dev All identity related contracts are deployed (Wallet, Name Service register)
    /// @param _identityOwner Account owner of the identity
    /// @param _identityRecovery Account recovery of the identity 
    /// @param _dataHash Hash of plain text data of the user of the identity 
    /// @param _name Nickname of the identity for Name Service 
    /// @return Address of the identity 
    function deployIdentity(
        address payable _identityOwner, 
        address payable _identityRecovery, 
        bytes32 _dataHash, 
        string calldata _name
    ) 
        external 
        isOn 
        onlyBackend 
        returns(address) 
    {
        (address _identityAddress, address _walletAddress) = _deployIdentity(
            _identityOwner, 
            _identityRecovery, 
            _dataHash,
            _name
        );
        
        PIBNameService _nameService = PIBNameService(controller.addresses(6)); //NameService
        _nameService.createName(_name, address(uint160(_walletAddress)), _identityAddress);
        
        emit DeployIdentity(_identityAddress, 
            _identityOwner, 
            _identityRecovery, 
            _walletAddress, 
            _name, 
            _dataHash
        );
        
        return (_identityAddress);
    }
    
    /// @notice Deploy a new Identity Contract 
    /// @dev All identity related contracts are deployed and identity is registered in Registry contract 
    /// @param _identityOwner Account owner of the identity
    /// @param _identityRecovery Account recovery of the identity 
    /// @param _dataHash Hash of plain text data of the user of the identity 
    /// @param _name Nickname of the identity for Name Service 
    /// @return Address of the identity 
    function _deployIdentity(
        address _identityOwner, 
        address _identityRecovery, 
        bytes32 _dataHash, 
        string memory _name
    ) 
        internal 
        returns(address, address) 
    {
        PIBIdentityDiamond _identity = new PIBIdentityDiamond(
            _identityOwner, 
            _identityRecovery, 
            _name, 
            address(controller)
        );
        
        PIBWalletFactory _walletFactory = PIBWalletFactory(controller.addresses(3)); //WalletFactory
        address _walletAddress = _walletFactory.deployWallet(address(_identity));
        
        PIBRegistry _registry = PIBRegistry(address(uint160(controller.addresses(1)))); //Registry
        _registry.setNewIdentity(address(_identity), _dataHash);
        
        return (address(_identity), _walletAddress);
    }
}