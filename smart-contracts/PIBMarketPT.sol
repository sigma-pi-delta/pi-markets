pragma solidity 0.5.0;

import "./safeMath.sol";
import "./tokens/utils/fiat/IRC223.sol";
import "./tokens/utils/fiat/ERC223_receiving_contract.sol";
import "./PIBController.sol";

/// @title Contract designed to handle exchange markets of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Exchanges of currencies
/// @dev P2P exchanges to an official change

contract PIBMarketPT is ERC223ReceivingContract {
    using SafeMath for uint;
    
    mapping(address => uint) public tokenBalances; //counterparts token balances  
    mapping(address => uint) public piBalances; //counterparts pi balances
    mapping(address => bool) public isPendingCounterpart;
    
    bool public on;
    uint public change; //change PI/TOKEN
    uint public commission; //commission in % (for 1% use 1 ether, 1e18)
    uint public popPtrPi; //pointer for counterpart selection in array 
    uint public popPtrToken; //pointer for counterpart selection in array 
    uint public piCounterpartBalance; //total pi balance of market
    uint public tokenCounterpartBalance; //total token balance of market 
    address payable[] public counterpartPi; //array of pi counterparts 
    address payable[] public counterpartToken; //array of token counterparts
    
    IRC223 public token;
    PIBController public controller;
    
    modifier isOn {
        require(on);
        _;
    }
    
    modifier onlyOwner {
        require(msg.sender == controller.owner());
        _;
    }
    
    event NewChange(address sender, uint change);
    event NewCommission(uint prev, uint current);
    event BuyPi(address indexed to, uint piAmount);
    event SellPi(address indexed to, uint tokenAmount);
    event SetCounterpart(address indexed tokenAddress, address indexed counterpart, uint amount);
    event PayCounterpart(address indexed tokenAddress, address indexed counterpart, uint amount);
    event WithdrawCounterpart(address indexed tokenAddress, address indexed counterpart, uint amount);
    
    constructor(uint _change, uint _commission, address _tokenAddress, address _controllerAddress) public {
        on = true;
        change = _change;
        commission = _commission;
        token = IRC223(_tokenAddress);
        controller = PIBController(_controllerAddress);
    }
    
    function () external payable {
        revert();
    }
    
    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/
    
    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() public {
        require(msg.sender == controller.switcher());
        on = !on;
    }
    
    /// @notice Set type of change PI/TOKEN 
    /// @dev Value in ether, use type of change * 1e18
    /// @param _newChange New type of change 
    function setChange(uint _newChange) public onlyOwner {
        change = _newChange;
        
        emit NewChange(tx.origin, change);
    }
    
    /// @notice Set commission
    /// @dev Value in % (for 1% use 1 ether, 1e18)
    /// @param _newCommission New commission
    function setCommission(uint _newCommission) public onlyOwner {
        emit NewCommission(commission, _newCommission);
        
        commission = _newCommission;
    }
    
    /***************************************************************/
    // VIEW FUNCTIONS
    /***************************************************************/
    
    /// @notice Get total balance of the contract 
    /// @return Token balance 
    /// @return PI balance 
    function contractBalance() public view returns (uint, uint) {
        uint _tokenBalance = token.balanceOf(address(this));
        uint _piBalance = address(this).balance;
        
        return (_tokenBalance, _piBalance);
    }
    
    /// @notice Get counterpart's balance 
    /// @return Token balance 
    /// @return PI balance 
    function balanceOf(address _who) public view returns (uint, uint) {
        //si quiero devolver tambien la posicion en cola del usuario crear un mapping 
        //con el indice de ese address en el array y restarle el popPtr 
        return (tokenBalances[_who], piBalances[_who]);
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
        public 
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
    
    /// @notice Be a counterpart with PI 
    /// @dev Sender cannot be a counterpart before. Send PI amount in msg.value 
    function piCounterpart() external isOn payable {
        require(!isCounterpartPi(msg.sender));
        _pushCounterpartPi(msg.sender);
        piBalances[msg.sender] = msg.value;
        piCounterpartBalance = piCounterpartBalance.add(msg.value);

        emit SetCounterpart(address(0), msg.sender, msg.value);
    }
    
    /// @notice Make an exchange sending PI and receiving token 
    /// @dev Amount in msg.value 
    function sellPi() external isOn payable {
        _sellPi(msg.value);
    }
    
    /// @notice Be a counterpart with token. Sender cannot be a counterpart before
    /// @dev Follows the scheme approve-transferFrom-disapprove to charge token 
    /// @param _amount Amount of token to be a counterpart with (and to charge)
    function tokenCounterpart(uint _amount) public {
        require(!isCounterpartToken(msg.sender));
        _pushCounterpartToken(msg.sender);
        tokenBalances[msg.sender] = _amount;
        _chargeToken(_amount);
        tokenCounterpartBalance = tokenCounterpartBalance.add(_amount);

        emit SetCounterpart(address(token), msg.sender, _amount);
    }
    
    /// @notice Standard ERC223 function that will handle incoming token transfers
    /// @dev Executes an exchange when not pending counterpart and nothing when pending counterpart 
    /// @param _from Token sender address.
    /// @param _value Amount of tokens.
    function tokenFallback(address payable _from, uint _value) public isOn {
        require(msg.sender == address(token));
        
        if (isCounterpartToken(_from)) {
            require(isPendingCounterpart[_from]);
        } else {
            _buyPi(_value, _from);
        }
    }

    /// @notice Stop being a counterpart 
    /// @dev Send back left balance 
    function withdrawCounterpart(address _tokenAddress) public isOn {
        require((isCounterpartPi(msg.sender)) || (isCounterpartToken(msg.sender)));
        
        if ((piBalances[msg.sender] != 0) && (_tokenAddress == address(0))) {
            piCounterpartBalance = piCounterpartBalance.sub(piBalances[msg.sender]);
            msg.sender.transfer(piBalances[msg.sender]);

            emit WithdrawCounterpart(address(0), msg.sender, piBalances[msg.sender]);

            piBalances[msg.sender] = 0;
            //_popCounterpartPi(msg.sender); //ESTO ES SIN POP NO?
        }
        
        if ((tokenBalances[msg.sender] != 0) && (_tokenAddress == address(token))) {
            tokenCounterpartBalance = tokenCounterpartBalance.sub(tokenBalances[msg.sender]);
            token.transfer(msg.sender, tokenBalances[msg.sender]);

            emit WithdrawCounterpart(address(token), msg.sender, tokenBalances[msg.sender]);

            tokenBalances[msg.sender] = 0;
            //_popCounterpartToken(msg.sender); //ESTO ES SIN POP NO?
        }
    }
    
    /// @notice Check if an address is already a counterpart in Pi
    /// @param _who Address to check 
    /// @return True if counterpart, False if not 
    function isCounterpartPi(address _who) public view returns (bool) {
        return piBalances[_who] > 0;
    }
    
    /// @notice Check if an address is already a counterpart in Token 
    /// @param _who Address to check 
    /// @return True if counterpart, False if not 
    function isCounterpartToken(address _who) public view returns (bool) {
        return tokenBalances[_who] > 0;
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
        require(piCounterpartBalance >= _piAmount);
        //bucle para saldar contraparte(s)
        _settleLoop(_piAmount, _tokenAmount, true);
        piCounterpartBalance = piCounterpartBalance.sub(_piAmount);
        //se le transfiere el cambio 
        _who.transfer(_piAmount);

        emit BuyPi(_who, _piAmount);
    }
    
    /// @notice Exchange when sending PI (buying Token) 
    /// @param _piAmount Sent amount of PI 
    function _sellPi(uint _piAmount) internal {
        (uint _tokenAmount,) = getExchangeInfoSending(address(0), _piAmount);
        require(tokenCounterpartBalance >= _tokenAmount);
        _settleLoop(_tokenAmount, _piAmount, false);
        tokenCounterpartBalance = tokenCounterpartBalance.sub(_tokenAmount);
        token.transfer(msg.sender, _tokenAmount);

        emit SellPi(msg.sender, _tokenAmount);
    }
    
    /// @notice Settle counterparts balances for the exchange 
    /// @dev Go through counterparts array until exchange is completed 
    /// @param _exchangerAmount Amount sent by the user 
    /// @param _counterpartAmount Amount needed from the counterpart for the exchange 
    /// @param _side Side of the exchange (True for PI-TOKEN, False for TOKEN-PI)
    function _settleLoop(uint _exchangerAmount, uint _counterpartAmount, bool _side) internal {
        bool _completed;
        uint _settleExchangerAmount;
        uint _settleCounterpartAmount;
        
        //en cada iteración o se completa el intercambio o devuelve lo que resta para que se siga con 
        //el intercambio en la siguiente iteración con la siguiente contraparte 
        while(!_completed) {
            (_completed, _settleExchangerAmount, _settleCounterpartAmount) = _settle(_exchangerAmount, _counterpartAmount, _side);
            _exchangerAmount = _exchangerAmount.sub(_settleExchangerAmount);
            _counterpartAmount = _counterpartAmount.sub(_settleCounterpartAmount);
        }
    }
    
    /// @notice Individual settlement of the exchange for next counterpart
    /// @dev Executes complete/partial "order" for the exchange 
    /// @param _exchangerAmount Amount sent by the user 
    /// @param _counterpartAmount Amount needed from the counterpart for the exchange 
    /// @param _side Side of the exchange (True for PI-TOKEN, False for TOKEN-PI)
    /// @return Boolean to indicate if the exchange is complete or not 
    /// @return Amount of _exchangerAmount settled with current counterpart 
    /// @return Amount of _counterpartAmount settled with current counterpart
    function _settle(uint _exchangerAmount, uint _counterpartAmount, bool _side) internal returns(bool, uint, uint) {
        address payable _counterpart;
        uint _available;
        bool _completed;
        uint _settleAmount;
        uint _settlePercentage;
        
        //dependiendo del side la contraprte será la de pi o la de token 
        if (_side) {
            _counterpart = counterpartPi[popPtrPi];
            _available = piBalances[_counterpart];
        } else {
            _counterpart = counterpartToken[popPtrToken];
            _available = tokenBalances[_counterpart];
        }
        
        //dependiendo de la cantidad para el intercambio y la cantidad de contraparte...
        if (_available >= _exchangerAmount) {
            _completed = true;
            _settleAmount = _exchangerAmount;
            _settlePercentage = 100 ether;
            
            if (_side) {
                piBalances[_counterpart] = piBalances[_counterpart].sub(_settleAmount);
            } else {
                tokenBalances[_counterpart] = tokenBalances[_counterpart].sub(_settleAmount);
            }
        } else {
            _completed = false;
            _settleAmount = _available;
            _settlePercentage = _settleAmount.mul(100 ether).div(_counterpartAmount);
            
            if (_side) {
                piBalances[_counterpart] = 0;
                _popCounterpartPi(_counterpart);
            } else {
                tokenBalances[_counterpart] = 0;
                _popCounterpartToken(_counterpart);
            }
        }
        
        //cantidad que se ha intercambiado con la contraparte de esta iteración 
        uint _currentCounterpartAmount = _counterpartAmount.mul(_settlePercentage).div(100 ether);
        
        //realizar el pago a la contraparte 
        if (_side) {
            //pagar en separado cantidad y comision?
            token.transfer(_counterpart, _currentCounterpartAmount);

            emit PayCounterpart(address(token), _counterpart, _currentCounterpartAmount);
        } else {
            _counterpart.transfer(_currentCounterpartAmount);

            emit PayCounterpart(address(0), _counterpart, _currentCounterpartAmount);
        }
        
        return (_completed, _settleAmount, _currentCounterpartAmount);
    }
    
    /// @notice Pseudo-charge an amount of token to an address 
    /// @dev Implements transferFrom function and checks balance before and after
    /// @param _amount Amount of token 
    function _chargeToken(uint _amount) internal {
        uint _preBalance = token.balanceOf(address(this));
        isPendingCounterpart[msg.sender] = true;
        token.transferFrom(address(this), msg.sender);
        isPendingCounterpart[msg.sender] = false;
        uint _postBalance = token.balanceOf(address(this));
        require(_postBalance == _preBalance.add(_amount), "balances mismatch");
    }
    
    /// @notice "Pop" a counterpart of the array
    /// @dev Not really a pop, just increment the pointer
    /// @param _who Address of the counterpart to pop 
    function _popCounterpartPi(address _who) internal {
        popPtrPi = popPtrPi.add(1);
        piBalances[_who] = 0;
    }
    
    /// @notice Include a new counterpart 
    /// @dev Push counterpart address in the array 
    /// @param _who Counterpart's address 
    function _pushCounterpartPi(address payable _who) internal {
        counterpartPi.push(_who);
    }
    
    /// @notice "Pop" a counterpart of the array
    /// @dev Not really a pop, just increment the pointer
    /// @param _who Address of the counterpart to pop 
    function _popCounterpartToken(address payable _who) internal {
        popPtrToken = popPtrToken.add(1);
        tokenBalances[_who] = 0;
    }
    
    /// @notice Include a new counterpart 
    /// @dev Push counterpart address in the array 
    /// @param _who Counterpart's address 
    function _pushCounterpartToken(address payable _who) internal {
        //require(isTokenReceiver(_who), "no token receiver");
        counterpartToken.push(_who);
    }
    
    /// @notice Check if an address can receive token 
    /// @dev Checks if it implements tokenFallback function 
    /// @param _who Address to check 
    /// @return True if can receive, false if not 
    /*function _isTokenReceiver(address _who) internal returns(bool) {
        uint codeLength;
        bool success;
        bytes memory data;
        
        assembly {
            // Retrieve the size of the code on target address, this needs assembly .
            codeLength := extcodesize(_who)
        }
        
        if (codeLength>0) {
            (success, data) = _who.call(abi.encodeWithSignature("tokenFallback(address,uint256)", address(token), 0));
        }
        
        if (success) {
            return true;
        } else {
            return false;
        }
    }*/
}