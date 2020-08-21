pragma solidity 0.5.0;
pragma experimental ABIEncoderV2;

import "../safeMath.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../tokens/utils/collectable/ERC721.sol";
import "../tokens/utils/collectable/ERC721TokenReceiver.sol";
import "../tokens/utils/packable/PNFTInterface.sol";
import "../tokens/utils/packable/PNFTokenReceiver.sol";
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

contract PIBWalletFacet is 
    PIBWalletStorage,
    ERC223ReceivingContract, 
    ERC721TokenReceiver,
    PNFTokenReceiver,
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

    event LimitValue(address token, uint value);
    event LimitTo(address destination, bool isAllowed);
    event LimitDaily(address token, uint dayLimit);
    event UnlimitValue(address token);
    event UnlimitTo();
    event UnlimitDaily(address token);
    
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
        selectors.push(this.transferNFT.selector);
        selectors.push(this.transferNFTRef.selector);
        selectors.push(this.transferNFTDomain.selector);
        selectors.push(this.transferNFTRefDomain.selector);
        selectors.push(this.transferPNFT.selector);
        selectors.push(this.transferPNFTDomain.selector);
        selectors.push(this.forwardValue.selector);
        selectors.push(this.forwardValuePNFT.selector);
        selectors.push(this.forward.selector);
        selectors.push(this.limitValue.selector);
        selectors.push(this.limitTo.selector);
        selectors.push(this.unlimitValue.selector);
        selectors.push(this.unlimitTo.selector);
        selectors.push(this.kill.selector);
        selectors.push(this.getTokens.selector);
        selectors.push(this.getNFTokens.selector);
        //selectors.push(this.getInfo.selector);
        //selectors.push(this.getInfoPartial.selector);
        selectors.push(this.getTransferExchangeInfoSending.selector);
        selectors.push(this.getTransferExchangeInfoReceiving.selector);
        selectors.push(this.getExchangeInfoSending.selector);
        selectors.push(this.getExchangeInfoReceiving.selector);
        selectors.push(this.getValueToSpend.selector);
        selectors.push(this.getSpendToValue.selector);
        selectors.push(this.tokenFallback.selector);
        selectors.push(this.onERC721Received.selector);
        selectors.push(this.onPNFTReceived.selector);        
        selectors.push(this.limitDaily.selector);
        selectors.push(this.unlimitDaily.selector);

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

    function transferNFT(
        address _tokenAddress, 
        address _to, 
        uint _tokenId, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        require(_isAllowed(_tokenAddress, _to, 0), "082");
        bytes memory empty;

        ERC721 _token = ERC721(_tokenAddress);
        _token.safeTransferFrom(address(this), _to, _tokenId, empty);

        emit Transfer(_tokenAddress, _kind, _to, bytes32(0), _tokenId, 0, _data);
    }

    function transferNFTRef(
        address _tokenAddress, 
        address _to, 
        string memory _tokenRef, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        require(_isAllowed(_tokenAddress, _to, 0), "083");
        bytes memory empty;

        ERC721 _token = ERC721(_tokenAddress);
        uint _tokenId = _token.getIdByRef(_tokenRef);
        _token.safeTransferFrom(address(this), _to, _tokenId, empty);

        emit Transfer(_tokenAddress, _kind, _to, bytes32(0), _tokenId, 0, _data);
    }

    function transferNFTDomain(
        address _tokenAddress, 
        string memory _name, 
        uint _tokenId, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        address payable _toAddress = _getDomainAddr(_name);
        transferNFT(_tokenAddress, _toAddress, _tokenId, _data, _kind);
    }

    function transferNFTRefDomain(
        address _tokenAddress, 
        string memory _name, 
        string memory _tokenRef, 
        string memory _data,
        uint _kind
    ) 
        public 
        onlyOwner 
    {
        address payable _toAddress = _getDomainAddr(_name);
        transferNFTRef(_tokenAddress, _toAddress, _tokenRef, _data, _kind);
    }

    function transferPNFT(
        address _tokenAddress,
        address _to,
        bytes32 _tokenId,
        uint _value,
        string memory _data,
        uint _kind
    )
        public
        onlyOwner
    {
        require(_isAllowed(_tokenAddress, _to, _value), "084");
        bytes memory empty;
        PNFTInterface _token = PNFTInterface(_tokenAddress);
        _token.safeTransferFrom(address(this), _to, _tokenId, _value, empty);
        emit Transfer(_tokenAddress, _kind, _to, _tokenId, _value, 0, _data);
    }

    function transferPNFTDomain(
        address _tokenAddress,
        string memory _name,
        bytes32 _tokenId,
        uint _value,
        string memory _data,
        uint _kind
    )
        public
        onlyOwner
    {
        address payable _toAddress = _getDomainAddr(_name);
        transferPNFT(_tokenAddress, _toAddress, _tokenId, _value, _data, _kind);
    }
    
    /*function setDexOrder(
        address _tokenAddress, 
        uint _value, 
        address _receiving, 
        uint _price, 
        uint _side, 
        address _exchangeAddress,
        uint _kind
    ) 
        public 
        onlyOwner 
        returns(bytes32) 
    {
        bytes32 _orderId;
        
        if (_tokenAddress == address(0)) {
            IPIDEX _dex = IPIDEX(_exchangeAddress);
            _orderId = _dex.setPiOrder.value(_value)(_receiving, _price, _side);
        } else {
            IRC223 _token = IRC223(_tokenAddress);
            _orderId = _token.setDexOrder(_value, _receiving, _price, _side, _exchangeAddress);
        }
        
        emit Transfer(_tokenAddress, _kind, _exchangeAddress, bytes32(0), _value, 0, "DEX Order");
        
        return _orderId;
    }*/
    
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
        uint _commission;
        
        if (_tokenAddress == address(0)) {
            if (controller.kinds(_destination) == 0) {
                _commission = _amountOrId.mul(controller.commission()).div(100 ether);
                address payable _collector = address(uint160(controller.addresses(7))); //Collector
                _collector.transfer(_commission);
            }

            (bool _success, bytes memory _result2) = _destination.call.value(_amountOrId)(_data);
            _result = _result2;
        
            if (!_success) {
                revert();
            }
        } else if (controller.isToken(_tokenAddress)) {
            IRC223 _token = IRC223(_tokenAddress);
            
            if (controller.kinds(_destination) == 0) {
                _commission = _amountOrId.mul(controller.commission()).div(100 ether);
                address payable _collector = address(uint160(controller.addresses(7))); //Collector
                _token.transfer(_collector, _commission);
            }

            _token.approve(_destination, _amountOrId);
            _result = forward(_destination, _data);
            _token.approve(_destination, 0);
        } else if (controller.isNFToken(_tokenAddress)) {
            ERC721 _token = ERC721(_tokenAddress);
            _token.approve(_destination, _amountOrId);
            _result = forward(_destination, _data);
        }

        emit Transfer(_tokenAddress, 0, _destination, bytes32(0), _amountOrId, _commission, "ForwardValue");

        return _result;
    }

    function forwardValuePNFT(
        address _tokenAddress, 
        bytes32 _tokenId,
        uint _amount, 
        address _destination, 
        bytes memory _data
    ) 
        public 
        onlyOwner 
        returns (bytes memory) 
    {
        bytes memory _result;
        uint _commission;
        
        PNFTInterface _token = PNFTInterface(_tokenAddress);
        _token.approve(address(this), _destination, _tokenId, _amount);
        _result = forward(_destination, _data);

        emit Transfer(_tokenAddress, 0, _destination, _tokenId, _amount, _commission, "ForwardValue");

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
            revert();
        }
        
        return _result;
    }
    
    /// @notice Set a limit to the value of transfers by currency 
    /// @dev Identity contract or recovery account of Identity can call this function 
    /// @param _tokenAddress Currency to set value limit 
    /// @param _limit Limit value for transfers
    function limitValue(address _tokenAddress, uint _limit) public ownerOrRecovery {
        if (isValueLimited[_tokenAddress]) {
            PIBIdentityFacet _identity = PIBIdentityFacet(address(uint160(owner)));
            address _recovery = _identity.recovery();
            require(msg.sender == _recovery, "085");
        }

        isValueLimited[_tokenAddress] = true;
        maxValues[_tokenAddress] = _limit;

        emit LimitValue(_tokenAddress, _limit);
    }
    
    /// @notice Limit the destinations of the transfers 
    /// @dev Identity contract or recovery account of Identity can call this function 
    /// @param _receiver Allowed receiver
    function limitTo(address _receiver, bool _isAllowed) public onlyRecovery {
        isToLimited = true;
        allowedReceiver[_receiver] = _isAllowed;
        emit LimitTo(_receiver, _isAllowed);
    }

    function limitDaily(address _tokenAddress, uint _limit) public ownerOrRecovery {
        if (isDayLimited[_tokenAddress]) {
            PIBIdentityFacet _identity = PIBIdentityFacet(address(uint160(owner)));
            address _recovery = _identity.recovery();
            require(msg.sender == _recovery, "086");
        }
        isDayLimited[_tokenAddress] = true;
        dayLimits[_tokenAddress] = _limit;
        emit LimitDaily(_tokenAddress, _limit);
    }
    
    /// @notice Remove the value limit for transfers 
    /// @dev Only recovery account of Identity can call (for prevention if owner is stolen)
    function unlimitValue(address _tokenAddress) public onlyRecovery {
        isValueLimited[_tokenAddress] = false;
        emit UnlimitValue(_tokenAddress);
    }
    
    /// @notice Remove the destination limit for transfers 
    /// @dev Only recovery account of Identity can call (for prevention if owner is stolen)
    function unlimitTo() public onlyRecovery {
        isToLimited = false;
        emit UnlimitTo();
    }

    function unlimitDaily(address _tokenAddress) public onlyRecovery {
        isDayLimited[_tokenAddress] = false;
        emit UnlimitDaily(_tokenAddress);
    }
    
    /// @notice Destroy wallet contract 
    /// @dev It sends all tokens and PI before selfdestruct 
    /// @param _collector Address to send all currencies before selfdestruct
    function kill(address payable _collector) public onlyRecovery {
        for (uint i = 0; i < tokens.length; i++) {
            IRC223 _token = IRC223(tokens[i]);
            _token.transfer(_collector, _token.balanceOf(address(this)));
        }

        for (uint j = 0; j < nfts.length; j++) {
            ERC721 _nft = ERC721(nfts[j]);
            uint _balance = _nft.balanceOf(address(this));
            require(_balance == 0, "087");
        }
        
        _collector.transfer(address(this).balance);
        _kill(_collector);
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
    
    /// @notice Get array with all type of tokens in the wallet 
    /// @return Array with tokens' addresses
    function getTokens() public view returns(address[] memory) {
        return tokens;
    }

    function getNFTokens() public view returns(address[] memory) {
        return nfts;
    }
    
    /// @notice Get balances of wallet 
    /// @return Array with addresses 
    /// @return Array with balances 
    /// @return Array with symbols 
    /*function getInfo() public view returns(address[] memory, uint[] memory, string[] memory) {
        return getInfoPartial(0, tokens.length);
    }*/
    
    /// @notice Get SOME balances of wallet 
    /// @dev In case tokens array is very long, get by parts
    /// @return Array with addresses 
    /// @return Array with balances 
    /// @return Array with symbols 
    /*function getInfoPartial(
        uint _first, 
        uint _last
    ) 
        public 
        view 
        returns(address[] memory, uint[] memory, string[] memory) 
    {
        uint _length = _last.sub(_first);
        address[] memory _tokens = new address[](_length + 1);
        uint[] memory _balances = new uint[](_length + 1);
        string[] memory _symbols = new string[](_length + 1);
        
        for (uint i = _first; i < _last; i++) {
            IRC223 _token = IRC223(tokens[i]);
            _tokens[i] = tokens[i];
            _balances[i] = _token.balanceOf(address(this));
            _symbols[i] = _token.symbol();
        }
        
        _tokens[_tokens.length - 1] = address(0);
        _balances[_tokens.length - 1] = address(this).balance;
        _symbols[_tokens.length - 1] = "PI";
        
        return (_tokens, _balances, _symbols);
    }*/

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
    
    /// @dev Standard ERC223 function that will handle incoming token transfers
    /// @param _from Token sender address.
    /// @param _value Amount of tokens.
    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "088");
        
        //si es un token que nunca he recibido registrar para cuando haga kill 
        if (!isToken[msg.sender]) {
            tokens.push(msg.sender);
            isToken[msg.sender] = true;
        }
        
        emit Receive(msg.sender, _from, bytes32(0), _value);
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
        returns(bytes4)
    {
        require(controller.isNFToken(msg.sender), "089");

        if (!isNFToken[msg.sender]) {
            nfts.push(msg.sender);
            isNFToken[msg.sender] = true;
        }

        emit Receive(msg.sender, _from, bytes32(0), _tokenId);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function onPNFTReceived(
        address _operator,
        address _from,
        bytes32 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external
        returns(bytes4)
    {
        require(controller.isPNFToken(msg.sender), "090");
        emit Receive(msg.sender, _from, _tokenId, _amount);
        return bytes4(keccak256("onPNFTReceived(address,address,bytes32,uint256,bytes)"));
    }
    
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
        
        uint _commission = _value.mul(controller.commission()).div(100 ether);
        
        address payable _collector = address(uint160(controller.addresses(7))); //Collector
        
        if (_tokenAddress == address(0)) {
            _collector.transfer(_commission);
            _to.transfer(_value);
        } else {
            IRC223 _token = IRC223(_tokenAddress);
            _token.transfer(_collector, _commission);
            _token.transfer(_to, _value);
        }
        
        emit Transfer(_tokenAddress, _kind, _to, bytes32(0), _value, _commission, _data);
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
    
    /// @dev Selfdestruct call 
    /// @param _collector Address to send left PI in the contract 
    function _kill(address payable _collector) internal {
        selfdestruct(_collector);
    }
}