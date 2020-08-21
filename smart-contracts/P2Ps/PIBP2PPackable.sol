pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../tokens/utils/packable/PNFTInterface.sol";
import "../tokens/utils/packable/PNFTokenReceiver.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";

contract PIBP2PPackable is PNFTokenReceiver, ERC223ReceivingContract {
    using SafeMath for uint;

    struct Offer {
        address payable owner;
        address sellToken;
        bytes32 sellId;
        uint sellAmount;
        address buyToken;
        uint buyAmount;
        bool isPartial;
        uint minDealAmount;
        uint maxDealAmount;
    }

    PIBController public controller;
    uint public salt;
    uint public commission;
    bool public on;

    mapping(bytes32 => Offer) public offers;

    event NewOffer(
        address indexed owner, 
        address indexed sellToken, 
        address buyToken,
        bytes32 sellId,
        uint sellAmount,
        uint buyAmount,
        bool isPartial,
        uint minDealAmount,
        uint maxDealAmount,
        string description,
        bytes32 indexed offerId,
        uint[] metadata
    );

    event NewDeal(
        bytes32 indexed offerId, 
        address indexed buyer, 
        uint _sellAmount,
        uint _buyAmount
    );
    
    event UpdateOffer(bytes32 indexed offerId, bytes32 sellId, uint sellAmount, uint buyAmount);
    event CancelOffer(bytes32 indexed offerId);
    event NewCommission(uint commission);

    modifier onlyOwner {
        require(msg.sender == controller.owner(), "099");
        _;
    }

    modifier isOn {
        require(on, "100");
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

    function setCommission(uint _newCommission) public onlyOwner isOn {
        commission = _newCommission;

        emit NewCommission(commission);
    }

    /// @notice Switch ON/OFF the contract
    /// @dev Only callable by switcher
    function toggleSwitch() public {
        require(msg.sender == controller.switcher(), "101");
        on = !on;
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/

    function offer(
        address _sellToken, 
        bytes32 _sellId, 
        uint _sellAmount,
        address _buyToken, 
        uint _buyAmount,
        bool _isPartial,
        uint _minDealAmount,
        uint _maxDealAmount,
        string calldata _description,
        uint[] calldata _metadata
    ) 
        external 
        payable 
        returns (bytes32)
    {
        require(controller.isToken(_buyToken), "102");
        require(controller.isPNFToken(_sellToken), "103");

        uint _entireAmount = _sellAmount.div(1 ether).mul(1 ether);
        require(_sellAmount == _entireAmount, "142");
        _chargePNFToken(_sellToken, msg.sender, _sellId, _entireAmount);
        
        return _newOffer(
            _sellToken,
            _sellId,
            _entireAmount,
            _buyToken,
            _buyAmount,
            _isPartial,
            _minDealAmount,
            _maxDealAmount,
            _description,
            _metadata
        );
    }

    function deal(bytes32 _offerId, uint _buyAmount) external payable returns (bytes32) {
        require(offers[_offerId].buyAmount >= _buyAmount, "104");
        require(!_isPNFTExpired(offers[_offerId].sellToken, offers[_offerId].sellId), "105");
        
        uint _sellAmount;
        bytes32 _sellId = offers[_offerId].sellId;
        address _sellToken = offers[_offerId].sellToken;
        address _buyToken = offers[_offerId].buyToken;
        address payable _seller = offers[_offerId].owner;

        _chargeToken(_buyToken, msg.sender, _buyAmount);

        /**
        CUIDADO!!!! TIENEN QUE SER CANTIDADES ENTERAS
        FORZAR QUE SE ELIJA UNA CANTIDAD ENTERA SE SELLTOKENS
         */

        if (!offers[_offerId].isPartial) {
            require(_buyAmount == offers[_offerId].buyAmount, "114");
            _sellAmount = offers[_offerId].sellAmount;
            _updateOffer(_offerId, 0, 0, 0);
        } else {
            //calculo los montos a restar y transferir
            _sellAmount = _buyAmount.mul(
                offers[_offerId].sellAmount
            ).div(
                offers[_offerId].buyAmount
            );

            require(offers[_offerId].minDealAmount <= _sellAmount, "106");
            require(offers[_offerId].maxDealAmount >= _sellAmount, "107");

            _updateOffer(
                _offerId, 
                _sellId, 
                offers[_offerId].sellAmount.sub(_sellAmount), 
                offers[_offerId].buyAmount.sub(_buyAmount)
            );
        }

        uint _sellAmountEntire = _sellAmount.div(1 ether).mul(1 ether);
        require(_sellAmount == _sellAmountEntire, "108");

        _settleDeal(
            _offerId, 
            _seller, 
            msg.sender, 
            _sellToken,
            _buyToken,
            _sellId, 
            _sellAmount,
            _buyAmount
        );
    }

    function cancelOffer(bytes32 _offerId) external {
        require(msg.sender == offers[_offerId].owner, "109");
        bytes32 _id = offers[_offerId].sellId;
        address _tokenAddress = offers[_offerId].sellToken;
        uint _sellAmount = offers[_offerId].sellAmount;
        _updateOffer(_offerId, 0, 0, 0);
        _transferPNFT(_tokenAddress, _id, _sellAmount, msg.sender);

        emit CancelOffer(_offerId);
    }

    function updateBuyAmount(bytes32 _offerId, uint _buyAmount) external {
        require(msg.sender == offers[_offerId].owner, "110");
        _updateOffer(_offerId, offers[_offerId].sellId, offers[_offerId].sellAmount, _buyAmount);
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

    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "112");
    }
    
    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    function _newOffer(
        address _sellToken, 
        bytes32 _sellId, 
        uint _sellAmount,
        address _buyToken, 
        uint _buyAmount,
        bool _isPartial,
        uint _minDealAmount,
        uint _maxDealAmount,
        string memory _description,
        uint[] memory _metadata
    )
        private
        returns (bytes32)
    {
        bytes32 _offerId = bytes32(
            keccak256(
                abi.encodePacked(
                    _sellToken,
                    _sellId,
                    _buyToken,
                    _buyAmount,
                    msg.sender,
                    now,
                    salt++
                )
            )
        );
        
        offers[_offerId].owner = msg.sender;
        offers[_offerId].sellToken = _sellToken;
        offers[_offerId].sellId = _sellId;
        offers[_offerId].sellAmount = _sellAmount;
        offers[_offerId].buyToken = _buyToken;
        offers[_offerId].buyAmount = _buyAmount;
        offers[_offerId].isPartial = _isPartial;
        offers[_offerId].minDealAmount = _minDealAmount;
        offers[_offerId].maxDealAmount = _maxDealAmount;

        emit NewOffer(
            msg.sender,
            _sellToken,
            _buyToken,
            _sellId,
            _sellAmount,
            _buyAmount,
            _isPartial,
            _minDealAmount,
            _maxDealAmount,
            _description,
            _offerId,
            _metadata
        );

        return _offerId;
    }

    function _settleDeal(
        bytes32 _offerId, 
        address payable _seller, 
        address payable _buyer,
        address _sellToken,
        address _buyToken,
        bytes32 _sellId,
        uint _sellAmount,
        uint _buyAmount
    ) 
        private 
    {
        uint _commission = _buyAmount.mul(commission).div(100 ether);
        address payable _collector = address(uint160(controller.addresses(7))); //Collector
        uint _sellerAmount = _buyAmount.sub(_commission);

        _transfer(_buyToken, _commission, _collector);
        _transfer(_buyToken, _sellerAmount, _seller);
        _transferPNFT(_sellToken, _sellId, _sellAmount, _buyer);

        emit NewDeal(_offerId, msg.sender, _sellAmount, _buyAmount);
    }

    function _transfer(address _tokenAddress, uint _amount, address payable _to) private {
        if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                _to.transfer(_amount);
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transfer(_to, _amount);
            }
        } else {
            revert();
        }
    }

    function _transferPNFT(address _tokenAddress, bytes32 _tokenId, uint _amount, address payable _to) private {
        if (controller.isPNFToken(_tokenAddress)) {
            bytes memory empty;
            PNFTInterface _token = PNFTInterface(_tokenAddress);
            _token.safeTransferFrom(address(this), _to, _tokenId, _amount, empty);
        } else {
            revert();
        }
    }

    function _updateOffer(bytes32 _offerId, bytes32 _id, uint _sellAmount, uint _buyAmount) private {
        if ((_id == 0) && (_buyAmount == 0) && (_sellAmount == 0)) {
            delete offers[_offerId];
        } else {
            offers[_offerId].sellAmount = _sellAmount;
            offers[_offerId].buyAmount = _buyAmount;
        }        
        emit UpdateOffer(_offerId, _id, _sellAmount, _buyAmount);
    }

    function _chargeToken(address _tokenAddress, address payable _from, uint _amountOrId) private {
        if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                require(msg.value == _amountOrId, "113");
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transferFromValue(address(this), _from, _amountOrId);
            }
        } else {
            revert();
        }
    }

    function _chargePNFToken(address _tokenAddress, address payable _from, bytes32 _tokenId, uint _amount) private {
        if (controller.isPNFToken(_tokenAddress)) {
            require(!_isPNFTExpired(_tokenAddress, _tokenId), "140");
            bytes memory empty;
            PNFTInterface _token = PNFTInterface(_tokenAddress);
            _token.safeTransferFromApproved(_from, address(this), _tokenId, _amount, empty);
        } else {
            revert();
        }
    }

    function _isPNFTExpired(address _tokenAddress, bytes32 _tokenId) internal view returns (bool) {
        PNFTInterface _token = PNFTInterface(_tokenAddress);
        return _token.isExpired(_tokenId);
    }
}