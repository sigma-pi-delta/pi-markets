pragma solidity 0.5.0;

import "./PIBIdentityStorage.sol";

contract PIBIdentityDiamond is 
    PIBIdentityStorage
{
    constructor(
        address _owner, 
        address _recovery, 
        string memory _name, 
        address _controllerAddress
    ) 
        public 
    {
        version = 1;
        facetCategory = 1;
        state = 10;
        name = _name;
        owner = _owner;
        recovery = _recovery;
        minBalance = 10000000000000000; //0.01 PI
        rechargeAmount = 100000000000000000; //0.1 PI

        controller = PIBController(_controllerAddress);
    }

    function () external payable {
        address _facet = controller.facets(facetCategory, msg.sig);

        if (_facet != address(0)) {

            assembly {
              let ptr := mload(0x40)
              calldatacopy(ptr, 0, calldatasize())
              let result := delegatecall(gas(), _facet, ptr, calldatasize(), 0, 0)
              let size := returndatasize()
              returndatacopy(ptr, 0, size)
              switch result
              case 0 {revert(ptr, size)}
              default {return (ptr, size)}
            }
        } else {
            revert();
        }
    }
}