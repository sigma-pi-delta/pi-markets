pragma solidity 0.5.0;

import "./safeMath.sol";
import "./tokens/utils/fiat/IRC223.sol";
import "./tokens/utils/fiat/ERC223_receiving_contract.sol";
import "./PIBController.sol";

contract PIBMarketSimple is ERC223ReceivingContract {
    using SafeMath for uint;

    bool public on;
    uint public change; //change PI/TOKEN
    uint public commission; //commission in % (for 1% use 1 ether, 1e18)
    address public charger;

    IRC223 public token;
    PIBController controller;
    
    modifier isOn {
        require(on, "031");
        _;
    }
    
    modifier onlyOwner {
        require(msg.sender == controller.owner(), "032");
        _;
    }
    
    event NewChange(address sender, uint change);
    event NewCommission(uint prev, uint current);
    event BuyPi(address indexed to, uint piAmount);
    event SellPi(address indexed to, uint tokenAmount);

    constructor(
        uint _change, 
        uint _commission, 
        address _tokenAddress, 
        address _controllerAddress,
        address _charger
    ) 
        public 
    {
        on = true;
        change = _change;
        commission = _commission;
        token = IRC223(_tokenAddress);
        controller = PIBController(_controllerAddress);
        charger = _charger;
    }

    function () external payable {
        if (msg.sender != charger) {
            _sellPi(msg.value);
        }
    }

    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/

    function setCharger(address _newCharger) public {
        require(msg.sender == charger, "033");
        charger = _newCharger;
    }
    
    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() external {
        require(msg.sender == controller.switcher(), "034");
        on = !on;
    }
    
    /// @notice Set type of change PI/TOKEN 
    /// @dev Value in ether, use type of change * 1e18
    /// @param _newChange New type of change 
    function setChange(uint _newChange) external onlyOwner {
        change = _newChange;
        
        emit NewChange(tx.origin, change);
    }
    
    /// @notice Set commission
    /// @dev Value in % (for 1% use 1 ether, 1e18)
    /// @param _newCommission New commission
    function setCommission(uint _newCommission) external onlyOwner {
        emit NewCommission(commission, _newCommission);
        
        commission = _newCommission;
    }

    function withdrawl(address _currency, uint _amount) external onlyOwner {
        if (_currency == address(0)) {
            msg.sender.transfer(_amount);
        } else {
            token.transfer(msg.sender, _amount);
        }
    }

    /***************************************************************/
    // VIEW FUNCTIONS
    /***************************************************************/
    
    /// @notice Get total balance of the contract 
    /// @return Token balance 
    /// @return PI balance 
    function contractBalance() external view returns (uint, uint) {
        uint _tokenBalance = token.balanceOf(address(this));
        uint _piBalance = address(this).balance;
        
        return (_tokenBalance, _piBalance);
    }

    /// @notice Required amount to send in order to receive desired amount in exchange 
    /// @param _sendingToken Currency which is going to be sent
    /// @param _receivingAmount Desired amount (of the opposite currency) to be received
    /// @return Amount (in _sendingToken currency) to be send to the market 
    /// @return Commission for the exchange (in _sendingToken currency)
    function getExchangeInfoReceiving(
        address _sendingToken, 
        uint _receivingAmount
    ) 
        external 
        view 
        returns(uint, uint) 
    {
        bool _side = getSideWhenSending(_sendingToken);
        uint _sendingAmount;
        
        uint _aux = 100 ether;
        _aux = _aux.sub(commission);
        _aux = _aux.div(100);
        
        if (_side) {
            _sendingAmount = _receivingAmount.mul(1 ether).div(change.mul(_aux).div(1 ether));
        } else {
            _sendingAmount = _receivingAmount.mul(change).div(_aux);
        }
        
        return (_sendingAmount, _sendingAmount.mul(commission).div(100 ether));
    }
    
    /// @notice Received amount in exchange of sent amount 
    /// @param _sendingToken Currency which is going to be sent 
    /// @param _sendingAmount Intended amount (in _sendingToken currency) to be send
    /// @return Amount (of the opposite currency) that will be received 
    /// @return Commission for the exchange (in _sendingToken currency)
    function getExchangeInfoSending(
        address _sendingToken, 
        uint _sendingAmount
    ) 
        public 
        view 
        returns (uint, uint) 
    {
        bool _side = getSideWhenSending(_sendingToken);
        uint _commission;
        uint _exchangeAmount;
        uint _counterpartAmount;
        
        if (_side) {
            _commission = _sendingAmount.mul(commission).div(100 ether);
            _exchangeAmount = _sendingAmount.sub(_commission);
            _counterpartAmount = _exchangeAmount.mul(change).div(1 ether);
        } else {
            _commission = _sendingAmount.mul(commission).div(100 ether);
            _exchangeAmount = _sendingAmount.sub(_commission);
            _counterpartAmount = _exchangeAmount.mul(1 ether).div(change);
        }
        
        return (_counterpartAmount, _commission);
    }
    
    /// @notice Identify sending currency
    /// @dev Transform sending currency into a boolean
    /// @param _tokenAddress Currency address (0x00...0 for PI)
    /// @return True when PI, False when token 
    function getSideWhenSending(address _tokenAddress) public pure returns (bool) {
        if (_tokenAddress == address(0)) {
            return true;
        } else {
            return false;
        }
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/

    /// @notice Standard ERC223 function that will handle incoming token transfers
    /// @dev Executes an exchange when not pending counterpart and nothing when pending counterpart 
    /// @param _from Token sender address.
    /// @param _value Amount of tokens.
    function tokenFallback(address payable _from, uint _value) public isOn {
        require(msg.sender == address(token), "035");
        
        if (_from != charger) {
            _buyPi(_value, _from);
        }
    }


    /***************************************************************/
    // INTERNAL FUNCTIONS
    /***************************************************************/

    /// @notice Exchange when sending token (buying PI)
    /// @param _tokenAmount Sent amount of token 
    /// @param _who Address of the user 
    function _buyPi(uint _tokenAmount, address payable _who) internal {
        //obtener info del cambio
        (uint _piAmount,) = getExchangeInfoSending(address(token), _tokenAmount);
        uint _marketBalancePi = address(this).balance;
        require(_marketBalancePi >= _piAmount, "036");
        //se le transfiere el cambio 
        _who.transfer(_piAmount);

        emit BuyPi(_who, _piAmount);
    }
    
    /// @notice Exchange when sending PI (buying Token) 
    /// @param _piAmount Sent amount of PI 
    function _sellPi(uint _piAmount) internal {
        (uint _tokenAmount,) = getExchangeInfoSending(address(0), _piAmount);
        uint _marketBalanceToken = token.balanceOf(address(this));
        require(_marketBalanceToken >= _tokenAmount, "037");
        token.transfer(msg.sender, _tokenAmount);

        emit SellPi(msg.sender, _tokenAmount);
    }
}