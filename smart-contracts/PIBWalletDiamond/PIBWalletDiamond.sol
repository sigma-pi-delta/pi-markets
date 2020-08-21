pragma solidity 0.5.0;

import "./PIBWalletStorage.sol";

contract PIBWalletDiamond is 
    PIBWalletStorage
{
    event Receive(
        address indexed tokenAddress, 
        address indexed _from, 
        bytes32 indexed tokenId,
        uint value
    );

    constructor(
        address payable _identityAddress, 
        address _controllerAddress
    ) 
        public 
    {
        version = 1;
        facetCategory = 2;
        owner = _identityAddress;
        controller = PIBController(_controllerAddress);
    }

    function () external payable {

        if (msg.value == 0) {
            address _facet = controller.facets(facetCategory, msg.sig);

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
            emit Receive(address(0), msg.sender, bytes32(0), msg.value);
        }
    }
}