pragma solidity 0.5.0;

import "../safeMath.sol";
import "./PIBIdentityStorage.sol";
import "../PIBWalletDiamond/PIBWalletTransferInterface.sol";

/// @title Blockchain Identity for a user of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Represents the identity of a user
/// @dev Designed to manage all identity's addresses

contract PIBIdentityAddressManagerFacet is PIBIdentityStorage {
    using SafeMath for uint;
    
    modifier onlyOwner {
        require(msg.sender == owner, "073");
        _;
    }
    
    modifier onlyRecovery {
        require(msg.sender == recovery, "074");
        _;
    }
    
    modifier ownerOrRecovery {
        require((msg.sender == owner) || (msg.sender == recovery), "075");
        _;
    }
    
    event NewOwner(address sender, address old, address current);
    event NewRecovery(address old, address current);
    event NewName(address sender, string old, string current);
    event NewWallet(address sender, address old, address current);
    
    constructor(

    ) 
        public 
    {

    }
    
    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/
    
    /// @notice Change contract owner 
    /// @dev Only callable by owner or recovery 
    /// @param _newOwner Address of the new owner 
    function setOwner(address _newOwner) public ownerOrRecovery {
        emit NewOwner(msg.sender, owner, _newOwner);
        
        owner = _newOwner;
    }

    /// @notice Change contract recovery
    /// @dev Only callable by current recovery
    /// @param _newRecovery Address of the new owner 
    function setRecovery(address _newRecovery) public onlyRecovery {
        recovery = _newRecovery;
        
        emit NewRecovery(msg.sender, _newRecovery);
    }
    
    /// @notice Set Nickname of the Identity in Name Service 
    /// @dev Personal storage of the name, not really used 
    /// @param _name Nickname of the identity 
    function setName(string memory _name) public {
        require(msg.sender == controller.addresses(6), "076"); //NameService
        
        emit NewName(msg.sender, name, _name);
        name = _name;
    }
    
    /// @notice Set address of the contract wallet 
    /// @dev Used to locate current wallet contract 
    /// @param _walletAddress Address of the wallet 
    function setWallet(address _walletAddress) public {
        require(msg.sender == controller.addresses(3), "077"); //WalletFactory
        
        emit NewWallet(msg.sender, wallet, _walletAddress);
        
        wallet = _walletAddress;
        _setAddress(3, _walletAddress);
    }
    
    /***************************************************************/
    // VIEW FUNCTIONS
    /***************************************************************/
    
    
    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/
    
    
    /***************************************************************/
    // INTERNAL FUNCTIONS
    /***************************************************************/
    
    /// @notice Check EOAs balance to recharge when under minBalance
    /// @dev Recharge only if needed and posible but never revert
    function _checkEOABalance() internal {

        if (msg.sender.balance < minBalance) {
            
            if (wallet.balance > rechargeAmount) {
                PIBWalletTransferInterface _wallet = PIBWalletTransferInterface(address(uint160(wallet)));
                _wallet.transfer(
                    address(0), 
                    msg.sender, 
                    rechargeAmount, 
                    "Recharge EOA",
                    0
                );    
            }
        }
    }
    
    /// @notice Register a new address of certain kind 
    /// @dev Used when identity forwardFactory
    /// @param _kind Type or ID of the contract 
    /// @param _newAddress Address of the contract 
    function _setAddress(uint _kind, address _newAddress) internal {
        require(kinds[_newAddress] == 0, "078");

        kinds[_newAddress] = _kind;
    }
}