pragma solidity 0.5.0;

import "../safeMath.sol";
import "./PIBAuctionStorage.sol";
import "./PIBAuctionFactory.sol";

contract PIBAuctionDiamond is PIBAuctionStorage {
    using SafeMath for uint;

    constructor(
        address payable _owner,
        address _auditor,
        address[] memory _tokens, // [0] auctionToken, [1] bidToken
        uint[] memory _settings, // [0] minValue, [1] endTime
        uint _commission,
        address _controllerAddress
    ) public {
        owner = _owner;
        factory = msg.sender;
        auditor = _auditor;
        auctionToken = _tokens[0];
        bidToken = _tokens[1];
        minValue = _settings[0].mul(1 ether).div(10 ether);
        maxBid = _settings[0];
        endTime = _settings[1];
        commission = _commission;
        controller = PIBController(_controllerAddress);
    }

    function () external payable {
        PIBAuctionFactory _factory = PIBAuctionFactory(controller.addresses(20));
        address _facet = _factory.facets(msg.sig);

        require(_facet != address(0), "Function not found");

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
    }
}