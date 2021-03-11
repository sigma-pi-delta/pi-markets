pragma solidity 0.5.0;

import "../PIBController.sol";

/// @title Contract designed to handle orders in the DEX
/// @author Sigma Pi Delta Technologies S.L.

contract PIBDEXAllow {
    PIBController public controller;

    mapping(address => mapping(uint => bool)) public allowances;

    event SetAllowance(address indexed sender, uint[] indexes, bool allowance);
    event SetAllowanceArray(address[] senders, uint index, bool allowance);

    modifier onlyBackend {
        require(msg.sender == controller.backend(), "179");
        _;
    }

    constructor(address _controllerAddress) public {
        controller = PIBController(_controllerAddress);
    }

    function isAllowed(address sender) public view returns(bool) {
        if (controller.addresses(33) == msg.sender) {
            return allowances[sender][33];
        } else if (controller.addresses(34) == msg.sender) {
            return allowances[sender][34];
        }
        return true;
    }

    function setAllowance(address sender, uint[] memory indexes, bool allowance) public onlyBackend {
        for (uint i = 0; i < indexes.length; i++) {
            allowances[sender][indexes[i]] = allowance;
        }

        emit SetAllowance(sender, indexes, allowance);
    }

    function setAllowanceArray(address[] memory senders, uint index, bool allowance) public onlyBackend {
        for (uint i = 0; i < senders.length; i++) {
            allowances[senders[i]][index] = allowance;
        }

        emit SetAllowanceArray(senders, index, allowance);
    }
}