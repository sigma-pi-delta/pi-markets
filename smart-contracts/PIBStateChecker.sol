pragma solidity 0.5.0;

import "./safeMath.sol";
import "./PIBController.sol";

/// @title State Checker of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Checks if action is allowed for the identity state
/// @dev Checks kind of action with the state 

contract PIBStateChecker {
    using SafeMath for uint;
    
    PIBController public controller;
    
    address public futureStateCheckerAddress;
    bool public stopAll;
    
    constructor(address _controllerAddress) public {
        controller = PIBController(_controllerAddress);
    }
    
    modifier onlyOwner {
        require(msg.sender == controller.owner(), "023");
        _;
    }
    
    function toggleStop() external onlyOwner {
        stopAll = !stopAll;
    }
    
    /// @notice Extension of State checker contract 
    /// @dev When kind greater than 4 forward check to another contract 
    /// @param _futureStateCheckerAddress Address of the next State checker 
    function setFutureStateChecker(address _futureStateCheckerAddress) external onlyOwner {
        futureStateCheckerAddress = _futureStateCheckerAddress;
    }
    
    /// @notice Checks if an action is allowed 
    /// @dev Checks the kind of the action with the current state of the identity 
    /// @param _state State of the identity 
    /// @param _identityDestinationKind Kind of the destination address 
    /// @return True if action is allowed, false if not 
    function checkState(
        uint _state, 
        uint _identityDestinationKind, 
        address _destination
    ) 
        external 
        view 
        returns(bool) 
    {
        
        if (stopAll) {
            return false;
        }
        
        if (checkStateIndex(_state, 0)) {
            return false;
        }
        
        if (checkStateIndex(_state, 1)) {
            if ((_identityDestinationKind == 0) && (controller.kinds(_destination) == 0)) {
                return false;
            }
        }
        
        if (_identityDestinationKind == 3) {

            if (checkStateIndex(_state, 3)) {
                return false;
            }
        } else if (_identityDestinationKind == 4) {

            if (checkStateIndex(_state, 4)) {
                return false;
            }
        } else if (_identityDestinationKind >= 5) {
            
            if (futureStateCheckerAddress != address(0)) {
                PIBStateChecker _futureStateChecker = PIBStateChecker(futureStateCheckerAddress);
                bool _check = _futureStateChecker.checkState(_state, _identityDestinationKind, _destination);
                
                if (!_check) {
                    return false;
                }
            }
        }
        
        return true;
    }
    
    /// @notice Check if the "filter" of that index is active or not and must be checked
    /// @dev When the cipher in _index position is 0 or pair returns true, false in other case
    /// @param _state Current state 
    /// @param _index Index of the filter
    /// @return True if active, false if not
    function checkStateIndex(uint _state, uint _index) public pure returns(bool) {
        uint _factor = power(10, _index);
        return (((_state.div(_factor))%2) != 0);
    }
    
    /// @dev Implements mathematical power 
    /// @param A Base of the power 
    /// @param B Exponent of the power 
    /// @return Result
    function power(uint A, uint B) public pure returns (uint){ 
        return A**B;
    }
}