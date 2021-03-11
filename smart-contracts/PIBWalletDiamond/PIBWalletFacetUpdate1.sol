pragma solidity 0.5.0;
pragma experimental ABIEncoderV2;

import "../safeMath.sol";
import "../tokens/utils/fiat/IRC223.sol";
//import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../tokens/utils/collectable/ERC721.sol";
//import "../tokens/utils/collectable/ERC721TokenReceiver.sol";
//import "../tokens/utils/packable/PNFTInterface.sol";
//import "../tokens/utils/packable/PNFTokenReceiver.sol";
import "../PIBIdentityDiamond/PIBIdentityFacet.sol";
import "../PIBController.sol";
import "../PIBNameService.sol";
import "../PIBMarketPT.sol";
import "../PIBWalletMath.sol";
import "../helpers/IPIDEX.sol";
import "./PIBWalletStorage.sol";
import "../PIBFacetInterface.sol";
import "../PIBDayManager.sol";

/// @title Wallet Contract of PI Decentralized Bank 
/// @author Sigma Pi Delta Technologies S.L.
/// @notice Handle functions of a wallet
/// @dev Implements transfer and receive functions among others

contract PIBWalletFacetUpdate1 is 
    PIBWalletStorage,
    //ERC223ReceivingContract, 
    //ERC721TokenReceiver,
    //PNFTokenReceiver,
    PIBFacetInterface
{
    using SafeMath for uint;

    bytes4[] public selectors;
    
    event Transfer(
        address indexed tokenAddress, 
        uint indexed kind, 
        address indexed to, 
        bytes32 tokenId,
        uint value, 
        uint commission, 
        string data
    );

    event Receive(
        address indexed tokenAddress, 
        address indexed _from, 
        bytes32 indexed tokenId,
        uint value
    );
    
    modifier onlyOwner {
        require(msg.sender == owner, "079");
        _;
    }
    
    modifier onlyRecovery {
        PIBIdentityFacet _identity = PIBIdentityFacet(address(uint160(owner)));
        address _recovery = _identity.recovery();
        require(msg.sender == _recovery, "080");
        _;
    }
    
    modifier ownerOrRecovery {
        PIBIdentityFacet _identity = PIBIdentityFacet(address(uint160(owner)));
        address _recovery = _identity.recovery();
        require((msg.sender == owner) || (msg.sender == _recovery), "081");
        _;
    }
    
    constructor() public {

        selectors.push(this.transfer.selector);
        selectors.push(this.transferSending.selector);
        selectors.push(this.transferDomain.selector);
        selectors.push(this.transferExchangeReceiving.selector);
        selectors.push(this.transferExchangeSending.selector);
        selectors.push(this.transferDomainSending.selector);
        selectors.push(this.transferExchangeDomainReceiving.selector);
        selectors.push(this.transferExchangeDomainSending.selector);
        selectors.push(this.exchange.selector);
        selectors.push(this.forwardValue.selector);
        selectors.push(this.forward.selector);

        facetCategory = 2;
    }
    
    /// @notice Fallback function to receive PI 
    /// @dev Emits an event with reception params
    function () external payable {
        emit Receive(address(0), msg.sender, bytes32(0), msg.value);
    }
    
    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/
    
    /// @notice Make a PI/Token transfer 
    /// @param _tokenAddress Currency to transfer (Token address or 0x00..0 when PI)
    /// @param _to Destination address 
    /// @param _value Amount to transfer 
    /// @param _data Additional info of the transfer 
    function transfer(
        address _tokenAddress, 
        address payable _to, 
        uint _value, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        _transfer(_tokenAddress, _kind, _to, _value, _data);
    }
    
    /// @notice Make a PI/Token transfer with a max spent amount 
    /// @dev Transfer whose total spent amount (value_tx + commission) is _value
    /// @param _tokenAddress Currency to transfer (Token address or 0x00..0 when PI)
    /// @param _to Destination address 
    /// @param _value Total amount to spend (value_tx + commission)
    /// @param _data Additional info of the transfer 
    function transferSending(
        address _tokenAddress, 
        address payable _to, 
        uint _value, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        uint _transferValue = getValueToSpend(_value);
        _transfer(_tokenAddress, _kind, _to, _transferValue, _data);
    }
    
    /// @notice Make a PI/Token transfer to a Name
    /// @param _tokenAddress Currency to transfer (Token address or 0x00..0 when PI)
    /// @param _name Destination name
    /// @param _value Amount to transfer 
    /// @param _data Additional info of the transfer 
    function transferDomain(
        address _tokenAddress, 
        string memory _name, 
        uint _value, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        address payable _toAddress = _getDomainAddr(_name);
        _transfer(_tokenAddress, _kind, _toAddress, _value, _data);
    }
    
    /// @notice Make a PI/Token transfer with a previous currency exchange  
    /// @dev Indicating the amount the receiver will receive 
    /// @param _sendingToken Token to exchange 
    /// @param _transferingToken Token to transfer 
    /// @param _transferingAmount Amount the receiver will receive (in _transferingToken)
    /// @param _to Destination address 
    /// @param _data Additional info of the transfer 
    function transferExchangeReceiving(
        address _sendingToken, 
        address _transferingToken, 
        uint _transferingAmount, 
        address payable _to, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        uint _sendingAmount = getTransferExchangeInfoReceiving(
            _sendingToken, 
            _transferingToken, 
            _transferingAmount
        );
        exchange(_sendingToken, _transferingToken, _sendingAmount, _kind);
        _transfer(_transferingToken, _kind, _to, _transferingAmount, _data);
    }
    
    /// @notice Make a PI/Token transfer with a previous currency exchange  
    /// @dev Indicating the total amount to spend (value_tx + commission)
    /// @param _sendingToken Token to exchange 
    /// @param _transferingToken Token to transfer 
    /// @param _sendingAmount Amount the receiver will receive (in _transferingToken)
    /// @param _to Destination address 
    /// @param _data Additional info of the transfer
    function transferExchangeSending(
        address _sendingToken, 
        address _transferingToken, 
        uint _sendingAmount, 
        address payable _to, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        (uint _totalSpendingAmount, ) = getExchangeInfoSending(
            _sendingToken, 
            _transferingToken, 
            _sendingAmount
        );
        uint _transferingAmount = getValueToSpend(_totalSpendingAmount);
        exchange(_sendingToken, _transferingToken, _sendingAmount, _kind);
        _transfer(_transferingToken, _kind, _to, _transferingAmount, _data);
    }
    
    /// @notice Make a PI/Token transfer with a max spent amount to a name
    /// @dev Transfer whose total spent amount (value_tx + commission) is _value
    /// @param _tokenAddress Currency to transfer (Token address or 0x00..0 when PI)
    /// @param _name Destination name
    /// @param _value Total amount to spend (value_tx + commission)
    /// @param _data Additional info of the transfer 
    function transferDomainSending(
        address _tokenAddress, 
        string memory _name, 
        uint _value, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        uint _transferValue = getValueToSpend(_value);
        transferDomain(_tokenAddress, _name, _transferValue, _data, _kind);
    }
    
    /// @notice Make a PI/Token transfer with a previous currency exchange to a name
    /// @dev Indicating the amount the receiver will receive 
    /// @param _sendingToken Token to exchange 
    /// @param _transferingToken Token to transfer 
    /// @param _transferingAmount Amount the receiver will receive (in _transferingToken)
    /// @param _name Destination name 
    /// @param _data Additional info of the transfer 
    function transferExchangeDomainReceiving(
        address _sendingToken, 
        address _transferingToken, 
        uint _transferingAmount, 
        string memory _name, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        address payable _toAddress = _getDomainAddr(_name);
        transferExchangeReceiving(
            _sendingToken, 
            _transferingToken, 
            _transferingAmount, 
            _toAddress, 
            _data,
            _kind
        );
    }
    
    /// @notice Make a PI/Token transfer with a previous currency exchange to a name
    /// @dev Indicating the total amount to spend (value_tx + commission)
    /// @param _sendingToken Token to exchange 
    /// @param _transferingToken Token to transfer 
    /// @param _sendingAmount Amount the receiver will receive (in _transferingToken)
    /// @param _name Destination name 
    /// @param _data Additional info of the transfer
    function transferExchangeDomainSending(
        address _sendingToken, 
        address _transferingToken, 
        uint _sendingAmount, 
        string memory _name, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        address payable _toAddress = _getDomainAddr(_name);
        transferExchangeSending(
            _sendingToken, 
            _transferingToken, 
            _sendingAmount, 
            _toAddress, 
            _data,
            _kind
        );
    }
    
    /// @notice Execute a currency exchange 
    /// @dev Search the market of the par and execute a transaction 
    /// @param _sendingToken Address of the token to exchange
    /// @param _receivingToken Address of the token received in exchange 
    /// @param _amount Amount to exchange 
    function exchange(
        address _sendingToken, 
        address _receivingToken, 
        uint _amount,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        address payable _marketAddress = address(
            uint160(
                controller.markets(
                    _sendingToken, 
                    _receivingToken
                )
            )
        );

        _transferNoCommission(_sendingToken, _kind, _marketAddress, _amount, "Exchange");
    }
    
    /// @notice Make a call to another contract sending value (PI/TOKEN)
    /// @dev Scheme call.value() with PI and approve()-call()-disapprove() whith tokens
    /// @param _tokenAddress Currency to send (Token address or 0x00...0 when PI)
    /// @param _amount Amount to transfer 
    /// @param _destination Destination of the call 
    /// @param _data Encoded function signature and params of the call 
    function forwardValue(
        address _tokenAddress, 
        uint _amountOrId, 
        address _destination, 
        bytes memory _data
    ) 
        public 
        onlyOwner 
        returns (bytes memory) 
    {
        bytes memory _result;

        if (_tokenAddress == address(0)) {

            (bool _success, bytes memory _result2) = _destination.call.value(_amountOrId)(_data);
            _result = _result2;
        
            if (!_success) {
                string memory _msg = _getRevertMsg(_result);
                require(_success, _msg);
            }
        } else if (controller.isToken(_tokenAddress)) {
            IRC223 _token = IRC223(_tokenAddress);
            _token.approve(_destination, _amountOrId);
            _result = forward(_destination, _data);
            _token.approve(_destination, 0);
        } else if (controller.isNFToken(_tokenAddress)) {
            ERC721 _token = ERC721(_tokenAddress);
            _token.approve(_destination, _amountOrId);
            _result = forward(_destination, _data);
        }

        emit Transfer(_tokenAddress, 0, _destination, bytes32(0), _amountOrId, 0, "ForwardValue");

        return _result;
    }
    
    /// @notice Resend a call to another contract function
    /// @dev Make a call to function encoded in _data and address in _destination 
    /// @param _destination Address of the contract 
    /// @param _data Function signature and params encoded
    /// @return encoded result of function call
    function forward(
        address _destination, 
        bytes memory _data
    ) 
        public 
        onlyOwner 
        returns(bytes memory) 
    {
        (bool _success, bytes memory _result) = _destination.call(_data);
        
        if (!_success) {
            string memory _msg = _getRevertMsg(_result);
            require(_success, _msg);
        }
        
        return _result;
    }
    
    /***************************************************************/
    // VIEW FUNCTIONS
    /***************************************************************/

    function getSelectors () external view returns (bytes4[] memory) {
        return selectors;
    }

    function getFacetCategory() external view returns (uint) {
        return facetCategory;
    }

    /// @notice Received amount in exchange of sent amount 
    /// @param _sendingToken Currency which is going to be sent 
    /// @param _sendingAmount Intended amount (in _sendingToken currency) to be send
    /// @return Amount (of the opposite currency) that will be received 
    function getTransferExchangeInfoSending(
        address _sendingToken, 
        address _transferingToken, 
        uint _sendingAmount
    ) 
        public 
        view 
        returns(uint) 
    {
        PIBWalletMath _math = PIBWalletMath(controller.addresses(5));
        
        return _math.getTransferExchangeInfoSending(
            _sendingToken, 
            _transferingToken, 
            _sendingAmount
        );
    }
    
    /// @notice Required amount to send in order to receive desired amount in exchange 
    /// @param _sendingToken Currency which is going to be sent
    /// @param _receivingAmount Desired amount (of the opposite currency) to be received
    /// @return Amount (in _sendingToken currency) to be send to the market 
    function getTransferExchangeInfoReceiving(
        address _sendingToken, 
        address _transferingToken, 
        uint _receivingAmount
    ) 
        public 
        view 
        returns(uint) 
    {
        PIBWalletMath _math = PIBWalletMath(controller.addresses(5));
        
        return _math.getTransferExchangeInfoReceiving(
            _sendingToken, 
            _transferingToken, 
            _receivingAmount
        );
    }
    
    /// @notice Get received amount when sending a fixed amount to exchange
    /// @dev Indicating the total amount to spend (value_tx + commission)
    /// @param _sendingToken Currency to send 
    /// @param _receivingToken Currency to receive 
    /// @param _sendingAmount Total spent amount 
    /// @return Total received amount
    function getExchangeInfoSending(
        address _sendingToken, 
        address _receivingToken, 
        uint _sendingAmount
    ) 
        public 
        view 
        returns(uint, uint) 
    {
        address payable _marketAddress = address(
            uint160(
                controller.markets(
                    _sendingToken, 
                    _receivingToken
                )
            )
        );
        PIBMarketPT _market = PIBMarketPT(_marketAddress);
        return _market.getExchangeInfoSending(_sendingToken, _sendingAmount);
    }
    
    /// @notice Get required amount to spend to receive _receivingAmount in an exchange 
    /// @param _sendingToken Currency to send 
    /// @param _receivingToken Currency to receive 
    /// @param _receivingAmount Desired amount 
    /// @return Total amount to send to the exchange
    function getExchangeInfoReceiving(
        address _sendingToken, 
        address _receivingToken, 
        uint _receivingAmount
    ) 
        public 
        view 
        returns(uint, uint) 
    {
        address payable _marketAddress = address(
            uint160(
                controller.markets(
                    _sendingToken, 
                    _receivingToken
                )
            )
        );
        PIBMarketPT _market = PIBMarketPT(_marketAddress);
        return _market.getExchangeInfoReceiving(_sendingToken, _receivingAmount);
    }
    
    /// @notice Get transfer value to spend some total amount 
    /// @dev Total amount is transfer value + commission 
    /// @param _totalAmount Amount to spend 
    /// @return Transfer value 
    function getValueToSpend(uint _totalAmount) public view returns (uint) {
        PIBWalletMath _math = PIBWalletMath(controller.addresses(5));
        
        return _math.getValueToSpend(_totalAmount);
    }
    
    /// @notice Get spent amount to transfer value 
    /// @dev Spent amount is transfer value + commission 
    /// @param _transferValue Transfer value 
    /// @return Spent amount 
    function getSpendToValue(uint _transferValue) public view returns (uint) {
        PIBWalletMath _math = PIBWalletMath(controller.addresses(5));
        
        return _math.getSpendToValue(_transferValue);
    }
    
    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/
    
    
    /***************************************************************/
    // INTERNAL FUNCTIONS
    /***************************************************************/
    
    /// @notice Execute a transfer
    /// @dev It also substracts commission amount 
    /// @param _tokenAddress Currency to transfer (Token address or 0x00..0 when PI)
    /// @param _to Destination address 
    /// @param _value Amount to transfer 
    /// @param _data Additional info of the transfer 
    function _transfer(
        address _tokenAddress, 
        uint _kind, 
        address payable _to, 
        uint _value, 
        string memory _data
    ) 
        internal 
    {
        require(_isAllowed(_tokenAddress, _to, _value), "091");
        
        if (_tokenAddress == address(0)) {
            _to.transfer(_value);
        } else {
            IRC223 _token = IRC223(_tokenAddress);
            _token.transfer(_to, _value);
        }
        
        emit Transfer(_tokenAddress, _kind, _to, bytes32(0), _value, 0, _data);
    }

    /// @notice Execute a transfer without commission (for exchange transfers)
    /// @dev It also substracts commission amount 
    /// @param _tokenAddress Currency to transfer (Token address or 0x00..0 when PI)
    /// @param _to Destination address 
    /// @param _value Amount to transfer 
    /// @param _data Additional info of the transfer
    function _transferNoCommission(
        address _tokenAddress, 
        uint _kind, 
        address payable _to, 
        uint _value, 
        string memory _data
    ) 
        internal 
    {
        require(_isAllowed(_tokenAddress, _to, _value), "092");
        
        if (_tokenAddress == address(0)) {
            PIBMarketPT _market = PIBMarketPT(_to);
            _market.sellPi.value(_value)();
        } else {
            IRC223 _token = IRC223(_tokenAddress);
            _token.transfer(_to, _value);
        }
        
        emit Transfer(_tokenAddress, _kind, _to, bytes32(0), _value, 0, _data);
    }
    
    /// @notice Get address of a name in Name Service 
    /// @param _name Name to translate into address 
    /// @return Associated address 
    function _getDomainAddr(string memory _name) internal view returns (address payable) {
        PIBNameService _nameService = PIBNameService(controller.addresses(6));
        return address(uint160(_nameService.addr(_name)));
    }
    
    /// @notice Check if a transfer is allowed 
    /// @dev Check if wallet is Value or To Limited and its params
    /// @param _tokenAddress Currency to transfer 
    /// @param _to Transfer destination 
    /// @param _value Transfer value
    function _isAllowed(
        address _tokenAddress, 
        address _to, 
        uint _value
    ) 
        internal 
        returns (bool) 
    {
        if (isToLimited) {
            if (!allowedReceiver[_to]) {
                return false;
            }
        }
        
        if (isValueLimited[_tokenAddress]) {
            if (_value > maxValues[_tokenAddress]) {
                return false;
            }
        }

        if (isDayLimited[_tokenAddress]) {
            PIBDayManager _dayManager = PIBDayManager(controller.addresses(8)); //DayManager
            uint _day = _dayManager.getDay();

            if (_day > dayByToken[_tokenAddress]) {
                daySpent[_tokenAddress] = _value;
                dayByToken[_tokenAddress] = _day;
            } else {
                daySpent[_tokenAddress] = _value.add(daySpent[_tokenAddress]);
            }

            if (daySpent[_tokenAddress] > dayLimits[_tokenAddress]) {
                return false;
            }
        }
        
        return true;
    }

    
    function _getRevertMsg(bytes memory _returnData) public pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return 'Transaction reverted silently';

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}