pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../tokens/utils/fiat/IRC223.sol"; 
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";

contract PIBPayDividend is ERC223ReceivingContract {
    using SafeMath for uint;

    IRC223 public token;
    IRC223 public payToken;
    bool public isPaying;
    bool public isConfigured;
    bool public isCharged;
    uint public payAmount;
    uint public index;
    uint public counter;
    address payable[] public holders;

    PIBController public controller;

    mapping(address => uint) public balances;

    modifier onlyBackend {
        require(msg.sender == controller.backend());
        _;
    }

    constructor(address _controller) public {
        controller = PIBController(_controller);
    }

    function () external payable {
        require(isConfigured);
        require(address(payToken) == address(0));
        payAmount = address(this).balance;
        isConfigured = false;
        isCharged = true;
    }

    function tokenFallback(address payable _from, uint _value) public {
        require(isConfigured);
        require(address(payToken) == msg.sender);
        payAmount = payToken.balanceOf(address(this));
        isConfigured = false;
        isCharged = true;
    }

    function reset() public onlyBackend {
        require(token.balanceOf(address(this)) == 0);
        require(token.balanceOf(address(this)) == 0);
        holders.length = 0;
        isPaying = false;
        isConfigured = false;
        isCharged = false;
        token = IRC223(address(0));
        payToken = IRC223(address(0));
    }

    function config(address _token, address _payToken) public onlyBackend {
        require((!isPaying) && (holders.length == 0));
        token = IRC223(_token);
        payToken = IRC223(_payToken);
        isConfigured = true;
    }

    function addHolders(address payable[] memory _holders) public onlyBackend {
        require(isCharged);
        
        holders = _holders;
    }

    function getBalances() public onlyBackend {
        uint _balance;
        while((gasleft() > 50000) && (index < holders.length)) {
            _balance = token.balanceOf(holders[index]);
            balances[holders[index]] = _balance;
            index++;
            counter = counter.add(_balance);
        }

        if (index == holders.length - 1) {
            checkSupply();
            index = 0;
            counter = 0;
        }
    }

    function pay() public {
        require(isPaying);

        while((gasleft() > 100000) && (index < holders.length)) {
            _payHolder(holders[index]);
            index++;
        }

        if (index >= holders.length) {
            index = 0;
            isPaying = false;
            payAmount = 0;
        }
    }

    function _payHolder(address payable _holder) private {
        uint _amount = payAmount.mul(balances[_holder]).div(payAmount);

        if (address(payToken) == address(0)) {
            _holder.transfer(_amount);
        } else {
            payToken.transfer(_holder, _amount);
        }
    }

    function checkSupply() public onlyBackend {
        uint _totalSupply = token.totalSupply();

        if (_totalSupply == counter) {
            isPaying = true;
        }
    }
}