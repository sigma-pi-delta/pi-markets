pragma solidity 0.5.0;

import "../safeMath.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../tokens/utils/packable/PNFTInterface.sol";
import "../tokens/utils/packable/PNFTokenReceiver.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../PIBController.sol";
import "./PIBDEXAllow.sol";

/// @title Contract designed to handle orders in the DEX
/// @author Sigma Pi Delta Technologies S.L.

contract PIBDEXPackable is ERC223ReceivingContract, PNFTokenReceiver {
    using SafeMath for uint;

    struct Order {
        uint nonce;
        address payable owner;
        address sending;
        address receiving;
        bytes32 packableId;
        uint amount;
        uint price;
        uint side;
        bool open;
        bool close;
        bool cancelled;
        bool dealed;
    }

    mapping(bytes32 => Order) public orders;
    mapping(address => uint) public salt;
    mapping(address => mapping(bytes32 => uint)) public setInBlock;
    mapping(address => bool) public isBackend;

    bool public on;
    uint public commission;
    address payable public collector;
    uint public cancelBlocks;

    PIBController public controller;

    modifier onlyOwner {
        require(msg.sender == controller.owner(), "099");
        _;
    }

    modifier onlyBackend {
        require(isBackend[msg.sender], "179");
        _;
    }

    modifier onlyAllowed {
        address _address = controller.addresses(32);
        PIBDEXAllow _allow = PIBDEXAllow(_address);
        require(_allow.isAllowed(msg.sender), "194");
        _;
    }

    modifier isOn {
        require(on, "100");
        _;
    }

    constructor (
        address _controllerAddress,
        address[] memory _backends,
        address payable _collector,
        uint _commission
    ) 
    public 
    {
        on = true;
        controller = PIBController(_controllerAddress);
        cancelBlocks = 12;
        collector = _collector;
        commission = _commission;
        emit NewCommission(commission);

        for (uint i = 0; i < _backends.length; i++) {
            isBackend[_backends[i]] = true;    
        }
    }

    event SetOrder(
        address indexed owner, 
        address indexed buying, 
        address indexed selling, 
        uint[3] settings,  //price, amount, side
        bytes32 packableId, 
        bytes32 id
    );
    event SetOrderSilent(
        address indexed owner, 
        address indexed buying, 
        address indexed selling, 
        uint[3] settings,  //price, amount, side
        bytes32 packableId, 
        bytes32 id
    );
    event CancelOrder(
        address indexed owner, 
        address indexed buying, 
        address indexed selling, 
        uint amount, 
        uint price, 
        bytes32 id
    );
    event Deal(
        bytes32 indexed orderA, 
        bytes32 indexed orderB, 
        uint amountA, 
        uint amountB, 
        uint side
    );
    event UpdateOrder(bytes32 indexed id, uint amount);
    event NewCommission(uint newCommission);

    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/

    function setBackend(address _newBackend, bool _is) public onlyOwner {
        isBackend[_newBackend] = _is;
    }
    
    function changeCancelBlocks(uint nBlocks) public onlyOwner isOn {
        cancelBlocks = nBlocks;
    }

    function setCommission(uint _newCommission) public onlyOwner isOn {
        commission = _newCommission;

        emit NewCommission(commission);
    }

    function setCollector(address payable _newCollector) public onlyOwner isOn {
        collector = _newCollector;
    }

    function dealOrderArray(
        bytes32[] memory orderA, 
        bytes32[] memory orderB, 
        uint[] memory side
    ) 
        public 
        onlyBackend
        isOn
    {
        for (uint i = 0; i < orderA.length; i++) {
            _dealOrder(orderA[i], orderB[i], side[i]);
        }
    }

    function dealOrder(
        bytes32 orderA, 
        bytes32 orderB, 
        uint side
    ) 
        public 
        onlyBackend
        isOn
    {
        _dealOrder(orderA, orderB, side);
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/

    function setOrder(
        address _sending, 
        address _receiving, 
        uint[3] calldata _settings,  //_amount, _price, _side
        bytes32 _packableId
    ) 
        external 
        payable 
        isOn 
        onlyAllowed
        returns(bytes32) 
    {
        if (_settings[2] == 2) {
            require(!_isPNFTExpired(_receiving, _packableId), "140");
            uint _packableAmount = _settings[0].mul(1 ether).div(_settings[1]);
            _checkEntireAmount(_packableAmount);
            _charge(_sending, msg.sender, _settings[0]);
        } else if (_settings[2] == 1) {
            _checkEntireAmount(_settings[0]);
            _chargePNFToken(_sending, msg.sender, _packableId, _settings[0]);
        } else {
            bool _false;
            require(_false, "178");
        }

        bytes32 orderId = _setOrder(
            msg.sender, 
            _sending, 
            _settings, 
            _receiving, 
            _packableId
        );

        return orderId;
    }

    function setOrderSilent(
        address _sending, 
        address _receiving, 
        uint[3] calldata _settings,  //_amount, _price, _side
        bytes32 _packableId
    ) 
        external 
        payable 
        isOn 
        onlyAllowed
        returns(bytes32) 
    {
        if (_settings[2] == 2) {
            require(!_isPNFTExpired(_receiving, _packableId), "140");
            uint _packableAmount = _settings[0].mul(1 ether).div(_settings[1]);
            _checkEntireAmount(_packableAmount);
            _charge(_sending, msg.sender, _settings[0]);
        } else if (_settings[2] == 1) {
            _checkEntireAmount(_settings[0]);
            _chargePNFToken(_sending, msg.sender, _packableId, _settings[0]);
        } else {
            bool _false;
            require(_false, "178");
        }

        bytes32 orderId = _setOrderSilent(
            msg.sender, 
            _sending, 
            _settings, 
            _receiving, 
            _packableId
        );

        return orderId;
    }

    /// @dev Cancel an order
    /// @param orderId identifier of the order to cancel
    function cancelOrder(bytes32 orderId) public {
        require(msg.sender == orders[orderId].owner, "180");
        require(orders[orderId].open && !orders[orderId].cancelled, "181");
        require(setInBlock[msg.sender][orderId].add(cancelBlocks) < block.number, "182");
        orders[orderId].open = false;
        orders[orderId].cancelled = true;
        //transfer
        _transfer(orders[orderId].sending, orders[orderId].packableId, orders[orderId].amount, msg.sender);

        emit CancelOrder(
            orders[orderId].owner,
            orders[orderId].sending,
            orders[orderId].receiving,
            orders[orderId].amount,
            orders[orderId].price,
            orderId
        );
        delete orders[orderId];
    }

    /// @dev Function to receive token ERC223ReceivingContract
    /// @param _from account sending token
    /// @param _value amount of token
    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "112");
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
        require(controller.isPNFToken(msg.sender), "111");
        return bytes4(keccak256("onPNFTReceived(address,address,bytes32,uint256,bytes)"));
    }

    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    /// @dev The exchange orders a deal between two orders
    /// @param orderA the older order
    /// @param orderB the more recent order
    /// @param side direction of the deal
    /// @return newOrderId identifier of the new order (bytes32(0) when none)
    function _dealOrder(bytes32 orderA, bytes32 orderB, uint side) private {
        require(orders[orderA].open && orders[orderB].open, "183");
        require(!orders[orderA].close && !orders[orderB].close, "184");
        require(orders[orderA].sending == orders[orderB].receiving, "185");
        require(orders[orderA].receiving == orders[orderB].sending, "186");
        require(orders[orderA].packableId == orders[orderB].packableId, "189");

        if (side == 1) {
            require(orders[orderA].price <= orders[orderB].price, "187");
        } else if (side == 2) {
            require(orders[orderA].price >= orders[orderB].price, "188");
        }
        uint finalAmountA;
        uint finalAmountB;

        if (orders[orderA].side == 1) {
            finalAmountA = orders[orderA].amount;
            finalAmountB = orders[orderB].amount.mul(1 ether).div(orders[orderB].price);
        } else {
            finalAmountA = orders[orderA].amount.mul(1 ether).div(orders[orderA].price);
            finalAmountB = orders[orderB].amount;
        }

        uint finalAmount;
        
        // Partial orders
        if(finalAmountA > finalAmountB) {
            finalAmount = finalAmountB;
        } else {
            finalAmount = finalAmountA;
        }
        
        uint auxA = finalAmountA.sub(finalAmount); 
        uint auxB = finalAmountB.sub(finalAmount);

        //Desnormalizamos
        uint rest;

        if (orders[orderA].side == 1) {
            finalAmountA = finalAmount;
            finalAmountB = finalAmount.mul(orders[orderB].price).div(1 ether);
        } else {
            finalAmountA = finalAmount.mul(orders[orderB].price).div(1 ether);
            rest = finalAmount.mul(orders[orderA].price).div(1 ether);
            rest = rest.sub(finalAmountA);
            finalAmountB = finalAmount;
        }
        
        checkDeal(orderA, finalAmountA.add(rest), auxA);
        checkDeal(orderB, finalAmountB, auxB);
        
        //Transferir fondos

        //Transferir a A
        //_transfer(orders[orderA].receiving, orders[orderA].packableId, finalAmountB, orders[orderA].owner);
        _pay(orderA, finalAmountB);

        if (rest > 0) {
            _transfer(orders[orderA].sending, orders[orderA].packableId, rest, orders[orderA].owner);
        }
        
        //Transferir a B
        //_transfer(orders[orderB].receiving, orders[orderB].packableId, finalAmountA, orders[orderB].owner);
        _pay(orderB, finalAmountA);

        emit Deal(orderA, orderB, finalAmountA, finalAmountB, side);

        if (auxA <= 0) {
            delete orders[orderA];
        }

        if (auxB <= 0) {
            delete orders[orderB];
        }
    }

    /// @dev Set a new order in the exchange
    /// @param owner the owner of the order
    /// @param sending address of the token to sell (address(0) when selling PI)
    /// @param amount amount of PI/token to sell
    /// @param receiving address of the token to buy (address(0) when buying PI)
    /// @param price the price of the order
    /// @return orderId identifier of the order
    function _setOrder(
        address payable owner, 
        address sending, 
        uint[3] memory _settings,  //_amount, _price, _side
        address receiving, 
        bytes32 _packableId
    ) 
        private 
        returns (bytes32) 
    {
        bytes32 orderId = bytes32(keccak256(abi.encodePacked(block.timestamp, sending, receiving, _settings[0], _settings[1], _settings[2], salt[owner])));
        require(!orders[orderId].open && !orders[orderId].cancelled && !orders[orderId].dealed, "190");
        salt[owner]++;
        setInBlock[msg.sender][orderId] = block.number;
        orders[orderId].owner = owner;
        orders[orderId].sending = sending;
        orders[orderId].receiving = receiving;
        orders[orderId].amount = _settings[0];
        orders[orderId].price = _settings[1];
        orders[orderId].side = _settings[2];
        orders[orderId].packableId = _packableId;
        orders[orderId].open = true;
        emit SetOrder(orders[orderId].owner, orders[orderId].sending, orders[orderId].receiving, _settings, _packableId, orderId);
        return orderId;
    }

    function _setOrderSilent(
        address payable owner, 
        address sending, 
        uint[3] memory _settings,  //_amount, _price, _side
        address receiving, 
        bytes32 _packableId
    ) 
        private 
        returns (bytes32) 
    {
        bytes32 orderId = bytes32(keccak256(abi.encodePacked(block.timestamp, sending, receiving, _settings[0], _settings[1], _settings[2], salt[owner])));
        require(!orders[orderId].open && !orders[orderId].cancelled && !orders[orderId].dealed, "190");
        salt[owner]++;
        setInBlock[msg.sender][orderId] = block.number;
        orders[orderId].owner = owner;
        orders[orderId].sending = sending;
        orders[orderId].receiving = receiving;
        orders[orderId].amount = _settings[0];
        orders[orderId].price = _settings[1];
        orders[orderId].side = _settings[2];
        orders[orderId].packableId = _packableId;
        orders[orderId].open = true;
        emit SetOrderSilent(orders[orderId].owner, orders[orderId].sending, orders[orderId].receiving, _settings, _packableId, orderId);
        return orderId;
    }

    function checkDeal (bytes32 _orderId, uint _amount, uint _aux) internal {
        if (orders[_orderId].amount > _amount) {
            orders[_orderId].amount = orders[_orderId].amount.sub(_amount);
            emit UpdateOrder(_orderId, orders[_orderId].amount);
        }

        orders[_orderId].nonce ++;
        orders[_orderId].dealed = true;
        
        if (_aux <= 0) {
            orders[_orderId].amount = 0;
            orders[_orderId].open = false;
            orders[_orderId].close = true;
            emit UpdateOrder(_orderId, orders[_orderId].amount);
        }
    }

    function _pay(bytes32 _orderId, uint _amount) private {
        if (orders[_orderId].side == 1) {
            uint _commission = _amount.mul(commission).div(100 ether);
            uint _payAmount = _amount.sub(_commission);
            if (_commission > 0) {
                _transfer(orders[_orderId].receiving, orders[_orderId].packableId, _commission, collector);
            }
            _transfer(orders[_orderId].receiving, orders[_orderId].packableId, _payAmount, orders[_orderId].owner);
        } else if (orders[_orderId].side == 2) {
            _transfer(orders[_orderId].receiving, orders[_orderId].packableId, _amount, orders[_orderId].owner);
        }
    }

    function _transfer(address _tokenAddress, bytes32 _tokenId, uint _amount, address payable _to) private {
        if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                _to.transfer(_amount);
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transfer(_to, _amount);
            }
        } else if (controller.isPNFToken(_tokenAddress)) {
            bytes memory empty;
            PNFTInterface _token = PNFTInterface(_tokenAddress);
            _token.safeTransferFrom(address(this), _to, _tokenId, _amount, empty);
        } else {
            bool _false = false;
            require(_false, "191");
        }
    }

    function _charge(address _tokenAddress, address payable _from, uint _amountOrId) private {
        if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                require(msg.value == _amountOrId, "113");
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transferFromValue(address(this), _from, _amountOrId);
            }
        } else {
            bool _false = false;
            require(_false, "172");
        }
    }

    function _chargePNFToken(address _tokenAddress, address payable _from, bytes32 _tokenId, uint _amount) private {
        if (controller.isPNFToken(_tokenAddress)) {
            require(!_isPNFTExpired(_tokenAddress, _tokenId), "140");
            bytes memory empty;
            PNFTInterface _token = PNFTInterface(_tokenAddress);
            _token.safeTransferFromApproved(_from, address(this), _tokenId, _amount, empty);
        } else {
            bool _false = false;
            require(_false, "192");
        }
    }

    function _isPNFTExpired(address _tokenAddress, bytes32 _tokenId) internal view returns (bool) {
        PNFTInterface _token = PNFTInterface(_tokenAddress);
        return _token.isExpired(_tokenId);
    }

    function _checkEntireAmount(uint _amount) internal {
        uint _entireAmount = _amount.div(1 ether).mul(1 ether);
        require(_amount == _entireAmount, "142");
    }
}