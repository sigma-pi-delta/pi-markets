pragma solidity 0.5.0;

import "./PIBFacetInterface.sol";

contract PIBControllerDiamond {
    address public diamondOwner;
    bool public cuttable;
    bool public upgradable;

    mapping(uint => mapping(bytes4 => address)) public facets;

    event DiamondCut(
        bytes4 indexed selector, 
        address indexed oldFacet, 
        address indexed newFacet
    );

    modifier onlyDiamondOwner {
        require(msg.sender == diamondOwner, "005");
        _;
    }

    constructor(
        address[] memory _facets
    ) 
        public 
    {
        cuttable = true;
        upgradable = true;
        _diamondCut(_facets);
    }

    function stopCuts() external onlyDiamondOwner {
        cuttable = false;
    }

    function stopUpgrades() external onlyDiamondOwner {
        upgradable = false;
    }

    function setDiamondOwner(address _newDiamondOwner) external onlyDiamondOwner {
        diamondOwner = _newDiamondOwner;
    }

    function diamondCut(address[] calldata _addresses) external onlyDiamondOwner {
        require(upgradable, "006");
        _diamondCut(_addresses);
    }

    function _diamondCut(address[] memory _addresses) private {

        for (uint i = 0; i < _addresses.length; i++) {
            PIBFacetInterface _facet = PIBFacetInterface(_addresses[i]);
            uint _category = _facet.getFacetCategory();
            bytes4[] memory _selectors = _facet.getSelectors();

            for (uint j = 0; j < _selectors.length; j++) {
                if (facets[_category][_selectors[j]] != address(0)) {
                    require(cuttable, "007");
                }

                emit DiamondCut(_selectors[j], facets[_category][_selectors[j]], _addresses[i]);

                facets[_category][_selectors[j]] = _addresses[i];
            }
        }
    }
}