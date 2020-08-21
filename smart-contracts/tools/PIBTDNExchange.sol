pragma solidity 0.5.0;

import "../safeMath.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";

contract PIBTDNExchange is ERC223ReceivingContract {
    using SafeMath for uint;

    address public owner;
    address public tdn;
    address public prev1;
    address public prev2;

    constructor(address _owner, address _tdn, address _prev1, address _prev2) public {
        owner = _owner;
        tdn = _tdn;
        prev1 = _prev1;
        prev2 = _prev2;
    }

    function withdrawl(address _tokenAddress, uint _value) public {
        require(msg.sender == owner);
        IRC223 _token = IRC223(_tokenAddress);
        _token.transfer(msg.sender, _value);
    }

    function tokenFallback(address payable _from, uint _value) public {
        require((msg.sender == address(tdn)) || (msg.sender == address(prev1)) || (msg.sender == address(prev2)));
        
        if (msg.sender != address(tdn)) {
            sendTdn(_from, _value);
        }
    }

    function sendTdn(address _from, uint _value) private {
        IRC223 _tdn = IRC223(tdn);
        _tdn.transfer(_from, _value);
    }
}