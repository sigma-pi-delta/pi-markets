pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../native-tokens/TDNPriceOracleInterface.sol";

contract PIBP2PPrimary is ERC223ReceivingContract {
    using SafeMath for uint;

    struct Offer {
        address payable owner;
        address sellToken;
        uint sellAmount;
        uint commission;
        bool isPartial;
        address buyToken;
        uint buyAmount;
        uint minDealAmount;
        uint maxDealAmount;
    }

    PIBController public controller;
    uint public salt;
    uint public commission;
    bool public on;

    mapping(bytes32 => Offer) public offers;
    mapping(bytes32 => address) public offerFixedBuyer;
    mapping(address => mapping(address => bool)) public isOfferer;
    mapping(address => mapping(address => bool)) public allowedOffer;

    event NewOffer(
        address indexed owner, 
        address indexed sellToken, 
        address buyToken,
        uint sellAmount,
        uint buyAmount,
        bool isPartial,
        bool isBuyFiat,
        uint[3] limits,
        address auditor,
        string description,
        bytes32 indexed offerId,
        uint[] metadata
    );

    event NewDeal(bytes32 indexed dealId, bool success, address indexed sender);
    event NewPendingDeal(
        bytes32 indexed offerId, 
        bytes32 indexed dealId,
        address buyer,
        uint sellAmount,
        uint buyAmount
    );
    event UpdateOffer(bytes32 indexed offerId, uint sellAmount, uint buyAmount);
    event CancelOffer(bytes32 indexed offerId);
    event NewCommission(uint commission);
    event FixedBuyer(bytes32 offerId, address fixedBuyer);
    event SetOfferer(address offerer, address token, bool isOfferer);
    event SetAllowedOffer(address sellToken, address buyToken, bool isAllowed);

    modifier onlyOwner {
        require(msg.sender == controller.owner(), "038");
        _;
    }

    modifier onlyBackend {
        require(msg.sender == controller.backend(), "039");
        _;
    }

    modifier isOn {
        require(on, "040");
        _;
    }

    constructor(address _controllerAddress, uint _commission) public {
        controller = PIBController(_controllerAddress);
        commission = _commission;
        emit NewCommission(commission);
        on = true;
    }

    /***************************************************************/
    // OWNER FUNCTIONS
    /***************************************************************/

    function setOfferer(address _offerer, address _token, bool _isOfferer) public onlyOwner isOn {
        isOfferer[_offerer][_token] = _isOfferer;

        emit SetOfferer(_offerer, _token, _isOfferer);
    }

    function setAllowedOffer(address _sellToken, address _buyToken, bool _isAllowed) public onlyOwner isOn {
        allowedOffer[_sellToken][_buyToken] = _isAllowed;

        emit SetAllowedOffer(_sellToken, _buyToken, _isAllowed);
    }

    function setCommission(uint _newCommission) public onlyOwner isOn {
        commission = _newCommission;

        emit NewCommission(commission);
    }

    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() public {
        require(msg.sender == controller.switcher(), "041");
        on = !on;
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/

    function offerFixed(
        address[2] calldata _tokens,
        uint[2] calldata _amounts,
        bool[2] calldata _settings,
        uint[3] calldata _limits,
        address _auditor,
        string calldata _description,
        uint[] calldata _metadata,
        address _fixedBuyer
    ) 
        external 
        payable 
        returns (bytes32)
    {
        bytes32 _offerId = offer(_tokens, _amounts, _settings, _limits, _auditor, _description, _metadata);
        offerFixedBuyer[_offerId] = _fixedBuyer;
        emit FixedBuyer(_offerId, _fixedBuyer);
        return _offerId;
    }

    function offer(
        address[2] memory _tokens,
        uint[2] memory _amounts,
        bool[2] memory _settings,
        uint[3] memory _limits,
        address _auditor,
        string memory _description,
        uint[] memory _metadata
    ) 
        public 
        payable 
        returns (bytes32)
    {
        require(controller.isToken(_tokens[0]), "042");
        require(controller.isToken(_tokens[1]), "043");
        require(isOfferer[msg.sender][_tokens[0]], "093");
        require(allowedOffer[_tokens[0]][_tokens[1]], "094");
        require(_settings[1] == false, "098");
        
        _chargeToken(_tokens[0], msg.sender, _amounts[0]);
        
        return _newOffer(
            _tokens,
            _amounts,
            _settings,
            _limits,
            _auditor,
            _description,
            _metadata
        );
    }

    function deal(bytes32 _offerId, uint _buyAmount) external payable returns (bytes32) {
        require(offers[_offerId].buyAmount >= _buyAmount, "044");

        if (offerFixedBuyer[_offerId] != address(0)) {
            require(msg.sender == offerFixedBuyer[_offerId], "097");
        }

        uint _sellAmount;
        uint _offerSellAmount;
        uint _offerBuyAmount;
        uint _dealCommission;
        uint _offerCommission;

        _chargeToken(offers[_offerId].buyToken, msg.sender, _buyAmount);

        if (!offers[_offerId].isPartial) {
            require(_buyAmount == offers[_offerId].buyAmount, "049");

            _sellAmount = offers[_offerId].sellAmount;
            _offerSellAmount = 0;
            _offerBuyAmount = 0;
            _dealCommission = offers[_offerId].commission;
            _offerCommission = 0;
        } else {
            _sellAmount = _buyAmount.mul(
                offers[_offerId].sellAmount
            ).div(
                offers[_offerId].buyAmount
            );

            _dealCommission = _sellAmount.mul(
                offers[_offerId].commission
            ).div(
                offers[_offerId].sellAmount
            );

            _offerSellAmount = offers[_offerId].sellAmount.sub(_sellAmount);
            _offerBuyAmount = offers[_offerId].buyAmount.sub(_buyAmount);
            _offerCommission = offers[_offerId].commission.sub(_dealCommission);
        }

        require(offers[_offerId].minDealAmount <= _sellAmount, "045");
        require(offers[_offerId].maxDealAmount >= _sellAmount, "046");

        address _buyToken = offers[_offerId].buyToken;
        address _sellToken = offers[_offerId].sellToken;
        address payable _seller = offers[_offerId].owner;
        bytes32 _dealId = keccak256(abi.encodePacked(_offerId, now, salt++));

        emit NewPendingDeal(_offerId, _dealId, msg.sender, _sellAmount, _buyAmount);

        _updateOffer(_offerId, _offerSellAmount, _offerBuyAmount, _offerCommission);

        _transfer(_buyToken, _buyAmount, _seller);
        _transfer(_sellToken, _sellAmount, msg.sender);
        address payable _collector = address(uint160(controller.addresses(7))); //Collector
        _transfer(_sellToken, _dealCommission, _collector);

        emit NewDeal(_dealId, true, msg.sender);
    }

    function cancelOffer(bytes32 _offerId) external {
        require(msg.sender == offers[_offerId].owner, "053");
        uint _amount = offers[_offerId].sellAmount;
        uint _commission = offers[_offerId].commission;
        address _tokenAddress = offers[_offerId].sellToken;
        _updateOffer(_offerId, 0, 0, 0);
        _transfer(_tokenAddress, _amount.add(_commission), msg.sender);

        emit CancelOffer(_offerId);
    }

    function updateBuyAmount(bytes32 _offerId, uint _buyAmount) external {
        require(msg.sender == offers[_offerId].owner, "054");
        _updateOffer(_offerId, offers[_offerId].sellAmount, _buyAmount, offers[_offerId].commission);
    }
    
    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "056");
    }

    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    function _transfer(address _tokenAddress, uint _amount, address payable _to) private {
        if (controller.isToken(_tokenAddress)) {
            _transferToken(_tokenAddress, _amount, _to);
        } else {
            revert();
        }
    }

    function _transferToken(address _tokenAddress, uint _amount, address payable _to) private {
        if (_tokenAddress == address(0)) {
            _to.transfer(_amount);
        } else {
            IRC223 _token = IRC223(_tokenAddress);
            _token.transfer(_to, _amount);
        }
    }

    function _updateOffer(
        bytes32 _offerId, 
        uint _offerSellAmount, 
        uint _buyAmount, 
        uint _commission
    ) 
        private 
    {
        if ((_offerSellAmount == 0) && (_buyAmount == 0)) {
            delete offers[_offerId];
        } else {
            offers[_offerId].sellAmount = _offerSellAmount;
            offers[_offerId].buyAmount = _buyAmount;
            offers[_offerId].commission = _commission;
        }   

        emit UpdateOffer(_offerId, _offerSellAmount, _buyAmount);     
    }

    function _newOffer(
        address[2] memory _tokens,
        uint[2] memory _amounts,
        bool[2] memory _settings,
        uint[3] memory _limits,
        address _auditor,
        string memory _description,
        uint[] memory _metadata
    )
        private
        returns (bytes32)
    {
        bytes32 _offerId = bytes32(
            keccak256(
                abi.encodePacked(
                    _tokens[0],
                    _amounts[0],
                    _tokens[1],
                    _amounts[1],
                    msg.sender,
                    now,
                    salt++
                )
            )
        );

        offers[_offerId].owner = msg.sender;
        offers[_offerId].sellToken = _tokens[0];
        offers[_offerId].sellAmount = _amounts[0].sub(_amounts[0].mul(commission).div(100 ether));
        offers[_offerId].commission = _amounts[0].mul(commission).div(100 ether);
        offers[_offerId].isPartial = _settings[0];
        offers[_offerId].buyToken = _tokens[1];
        offers[_offerId].buyAmount = _amounts[1];
        offers[_offerId].minDealAmount = _limits[0];
        offers[_offerId].maxDealAmount = _limits[1];

        emit NewOffer(
            msg.sender,
            _tokens[0],
            _tokens[1],
            offers[_offerId].sellAmount,
            _amounts[1],
            _settings[0],            
            _settings[1],
            _limits,
            _auditor,
            _description,
            _offerId,
            _metadata
        );

        return _offerId;
    }

    function _chargeToken(address _tokenAddress, address payable _from, uint _amount) private {
        if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                require(msg.value == _amount, "058");
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transferFromValue(address(this), _from, _amount);
            }
        } else {
            revert();
        }
    }
}