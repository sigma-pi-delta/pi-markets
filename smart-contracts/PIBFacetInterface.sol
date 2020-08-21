pragma solidity 0.5.0;

interface PIBFacetInterface {
    function getSelectors () external view returns (bytes4[] memory);
    function getFacetCategory() external view returns (uint);
} 