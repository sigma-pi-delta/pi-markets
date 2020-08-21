pragma solidity 0.5.0;

import "./PIBIdentityAddressManagerFacet.sol";
import "../PIBStateChecker.sol";
import "../PIBFacetInterface.sol";
//import "./PIBIdentityStorage.sol";

/// @title Blockchain Identity for a user of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Represents the identity of a user
/// @dev Designed to forward calls to other contract from an identity 

contract PIBIdentityFacet is 
    PIBIdentityAddressManagerFacet, 
    PIBFacetInterface 
{
    bytes4[] public selectors;

    event Forward(address indexed destination, uint value, bytes data, bytes result);
    event FactoryForward(uint indexed kind, address contractAddress);
    
    constructor(

    ) 
        public 
    {

        selectors.push(this.forward.selector);
        selectors.push(this.forwardValue.selector);
        selectors.push(this.forwardFactory.selector);
        selectors.push(this.setState.selector);
        selectors.push(this.setOwner.selector);
        selectors.push(this.setRecovery.selector);
        selectors.push(this.setName.selector);
        selectors.push(this.setWallet.selector);

        facetCategory = 1;
    }
    
    function () external payable {
        revert();
    }
    
    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/
    
    /// @notice Resend a call to another contract function
    /// @dev Make a call to function encoded in _data and address in _destination 
    /// @param _destination Address of the contract 
    /// @param _data Function signature and params encoded
    /// @return encoded result of function call
    function forward(address _destination, bytes memory _data) public onlyOwner returns(bytes memory) {
        require(_checkState(_destination), "069");
        
        _checkEOABalance();
        
        bytes memory _result = _forward(_destination, _data);
        
        emit Forward(_destination, 0, _data, _result);
        
        return _result;
    }
    
    /// @notice Same as forward but sending value with the call 
    /// @dev Make a call to a payable function sending value in msg.value
    /// @param _destination Address of the contract 
    /// @param _data Function signature and params encoded
    /// @return encoded result of function call
    function forwardValue(
        address _destination, 
        bytes calldata _data
    ) 
        external 
        payable 
        
        onlyOwner 
        returns(bytes memory) 
    {
        require(_checkState(_destination), "070");
        
        _checkEOABalance();
        
        (bool _success, bytes memory _result) = _destination.call.value(msg.value)(_data);
        
        if (!_success) {
            revert();
        }
        
        emit Forward(_destination, msg.value, _data, _result);
        
        return _result;
    }
    
    /// @notice Same as forward with destination a factory contract 
    /// @dev After forward it registers the address of the already deployed contract and its kind 
    /// @param _factory Address of the factory contract 
    /// @param _data Function signature and params encoded
    /// @return address of the already deployed contract 
    function forwardFactory(address _factory, bytes memory _data) public onlyOwner returns(address) {
        require(controller.isFactory(_factory), "071");
        
        _checkEOABalance();
        
        bytes memory _result = _forward(_factory, _data);
        
        address _contractAddress = abi.decode(_result, (address));
        uint _kind = controller.kinds(_factory);
        _setAddress(_kind, _contractAddress);
        
        emit FactoryForward(_kind, _contractAddress);
        
        return _contractAddress;
    }
    
    /// @notice Change the state of the contract 
    /// @dev Disallow some forwards depending on the state number 
    /// @param _newState New state 
    function setState(uint _newState) public {
        require(msg.sender == recovery, "072");
        
        state = _newState;
    }

    /***************************************************************/
    // VIEW FUNCTIONS
    /***************************************************************/

    function getSelectors () external view returns (bytes4[] memory) {
        return selectors;
    }

    function getFacetCategory() external view returns (uint) {
        return facetCategory;
    }
    
    
    /***************************************************************/
    // INTERNAL FUNCTIONS
    /***************************************************************/
    
    /// @notice Make call and return the result 
    /// @dev Call function in destination, check success and return encoded result 
    /// @param _destination Address of the contract 
    /// @param _data Function signature and params encoded
    /// @return encoded result of function call
    function _forward(address _destination, bytes memory _data) internal returns (bytes memory) {
        (bool _success, bytes memory _result) = _destination.call(_data);
        
        if (!_success) {
            revert();
        }
        
        return _result;
    }
    
    /// @notice Check if the call is allowed 
    /// @dev Call stateChecker contract to check if call to _destination is allowed with identity's state 
    /// @param _destination Address of the contract 
    /// @return True if call is allowed, False if not 
    function _checkState(address _destination) internal view returns (bool) {
        PIBStateChecker _stateChecker = PIBStateChecker(controller.addresses(4)); //StateChecker
        return _stateChecker.checkState(state, kinds[_destination], _destination);
    }
}