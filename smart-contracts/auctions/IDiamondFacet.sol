pragma solidity ^0.5.0;

interface IDiamondFacet {
    function getSelectors () external view returns (bytes4[] memory);
} 