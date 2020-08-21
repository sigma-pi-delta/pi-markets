pragma solidity 0.5.0;

import "./PIBController.sol";
import "./PIBIdentityDiamond/PIBIdentityFacet.sol";
import "./PIBWalletDiamond/PIBWalletDiamond.sol";

/// @title Wallet Factory of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Handle Wallet creation
/// @dev Deployment of Wallet contract and Name reservation 

contract PIBWalletFactory {
    PIBController public controller;
    
    constructor(address _controllerAddress) public {
        controller = PIBController(_controllerAddress);
    }
    
    event NewWallet(address indexed identity, address indexed wallet);
    
    /// @notice Create a wallet without name 
    /// @param _identityAddress Address of the Identity contract 
    /// @return Address of the already deployed Wallet contract 
    function deployWallet(address payable _identityAddress) external returns (address) {
        require(msg.sender == controller.addresses(2), "011");
        
        PIBWalletDiamond _wallet = new PIBWalletDiamond(
            _identityAddress, 
            address(controller)
        );
        
        PIBIdentityFacet _identity = PIBIdentityFacet(_identityAddress);
        _identity.setWallet(address(_wallet));
        
        emit NewWallet(_identityAddress, address(_wallet));
        
        return (address(_wallet));
    }
}