pragma solidity ^0.5.0;

 /* New ERC223 contract interface */

contract IRC223 {
    uint public totalSupply;
    function balanceOf(address who) public view returns (uint);

    function name() external view returns (string memory _name);
    function symbol() external view returns (string memory _symbol);
    function decimals() external view returns (uint8 _decimals);

    function transfer(address to, uint value) external;
    function transferFrom (address _to, address payable _from) external;
    function transferFromValue (address _to, address payable _from, uint _value) external;
    function approve (address _to, uint _value) external;
    function disapprove (address _spender) external;
    function mint(address to, uint value) external;
    function burn(uint value) external;
    function setDexOrder(uint _value, address receiving, uint price, uint side, address exchangeAddress) external returns(bytes32);
    function setOwner(address newOwner) external;

    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}
