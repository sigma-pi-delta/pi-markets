pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../tokens/utils/collectable/ERC721.sol";
import "../tokens/utils/collectable/ERC721TokenReceiver.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";

contract PIBP2PCollectablePrimary is ERC721TokenReceiver, ERC223ReceivingContract {
    using SafeMath for uint;

    struct Offer {
        address payable owner;
        address sellToken;
        uint sellId;
        address buyToken;
        uint buyAmount;
    }

    PIBController public controller;
    uint public salt;
    uint public commission;
    bool public on;

    mapping(bytes32 => Offer) public offers;
    mapping(address => mapping(address => bool)) public isOfferer;
    mapping(address => mapping(address => bool)) public allowedOffer;

    event NewOffer(
        address indexed owner, 
        address indexed sellToken, 
        address buyToken,
        uint sellId,
        uint buyAmount,
        string description,
        bytes32 indexed offerId,
        uint[] metadata
    );

    event NewDeal(
        bytes32 indexed offerId, 
        address indexed buyer, 
        uint _buyAmount
    );
    
    event UpdateOffer(bytes32 indexed offerId, uint sellId, uint buyAmount);
    event CancelOffer(bytes32 indexed offerId);
    event NewCommission(uint commission);
    event SetOfferer(address offerer, address token, bool isOfferer);
    event SetAllowedOffer(address sellToken, address buyToken, bool isAllowed);

    modifier onlyOwner {
        require(msg.sender == controller.owner(), "059");
        _;
    }

    modifier isOn {
        require(on, "060");
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
        require(msg.sender == controller.switcher(), "061");
        on = !on;
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/

    function offer(
        address _sellToken, 
        uint _sellId, 
        address _buyToken, 
        uint _buyAmount,
        string calldata _description,
        uint[] calldata _metadata
    ) 
        external 
        payable 
        returns (bytes32)
    {
        require(isOfferer[msg.sender][_sellToken], "095");
        require(allowedOffer[_sellToken][_buyToken], "096");
        require(controller.isToken(_buyToken), "062");
        require(controller.isNFToken(_sellToken), "063");

        _chargeToken(_sellToken, msg.sender, _sellId);
        
        return _newOffer(
            _sellToken,
            _sellId,
            _buyToken,
            _buyAmount,
            _description,
            _metadata
        );
    }

    function deal(bytes32 _offerId) external payable returns (bytes32) {
        require(!_isNFTExpired(offers[_offerId].sellToken, offers[_offerId].sellId));

        uint _buyAmount = offers[_offerId].buyAmount;
        uint _sellId = offers[_offerId].sellId;
        address _sellToken = offers[_offerId].sellToken;
        address _buyToken = offers[_offerId].buyToken;
        address payable _seller = offers[_offerId].owner;

        _chargeToken(_buyToken, msg.sender, _buyAmount);
        _updateOffer(_offerId, 0, 0); //0,0 is to close the offer
        _settleDeal(
            _offerId, 
            _seller, 
            msg.sender, 
            _sellToken,
            _buyToken,
            _sellId, 
            _buyAmount
        );
    }

    function cancelOffer(bytes32 _offerId) external {
        require(msg.sender == offers[_offerId].owner, "064");
        uint _id = offers[_offerId].sellId;
        address _tokenAddress = offers[_offerId].sellToken;
        _updateOffer(_offerId, 0, 0);
        _transfer(_tokenAddress, _id, msg.sender);

        emit CancelOffer(_offerId);
    }

    function updateBuyAmount(bytes32 _offerId, uint _buyAmount) external {
        require(msg.sender == offers[_offerId].owner, "065");
        _updateOffer(_offerId, offers[_offerId].sellId, _buyAmount);
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
        require(controller.isNFToken(msg.sender), "066");
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "067");
    }
    
    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    function _newOffer(
        address _sellToken, 
        uint _sellId, 
        address _buyToken, 
        uint _buyAmount,
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
        offers[_offerId].buyToken = _buyToken;
        offers[_offerId].buyAmount = _buyAmount;

        emit NewOffer(
            msg.sender,
            _sellToken,
            _buyToken,
            _sellId,
            _buyAmount,
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
        uint _sellId,
        uint _buyAmount
    ) 
        private 
    {
        uint _commission = _buyAmount.mul(commission).div(100 ether);
        address payable _collector = address(uint160(controller.addresses(7))); //Collector
        uint _sellerAmount = _buyAmount.sub(_commission);

        _transfer(_buyToken, _commission, _collector);
        _transfer(_buyToken, _sellerAmount, _seller);
        _transfer(_sellToken, _sellId, _buyer);

        emit NewDeal(_offerId, msg.sender, _buyAmount);
    }

    function _transfer(address _tokenAddress, uint _amountOrId, address payable _to) private {
        if (controller.isNFToken(_tokenAddress)) {
            bytes memory empty;
            ERC721 _token = ERC721(_tokenAddress);
            _token.safeTransferFrom(address(this), _to, _amountOrId, empty);
        } else if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                _to.transfer(_amountOrId);
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transfer(_to, _amountOrId);
            }
        } else {
            revert();
        }
    }

    function _updateOffer(bytes32 _offerId, uint _id, uint _buyAmount) private {
        if ((_id == 0) && (_buyAmount == 0)) {
            delete offers[_offerId];
        } else {
            offers[_offerId].buyAmount = _buyAmount;
        }        
        emit UpdateOffer(_offerId, _id, _buyAmount);
    }

    function _chargeToken(address _tokenAddress, address payable _from, uint _amountOrId) private {
        if (controller.isNFToken(_tokenAddress)) {
            require(!_isNFTExpired(_tokenAddress, _amountOrId), "141");
            bytes memory empty;
            ERC721 _token = ERC721(_tokenAddress);
            _token.safeTransferFrom(_from, address(this), _amountOrId, empty);
        } else if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                require(msg.value == _amountOrId, "068");
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transferFromValue(address(this), _from, _amountOrId);
            }
        } else {
            revert();
        }
    }

    function _isNFTExpired(address _tokenAddress, uint _tokenId) internal view returns(bool) {
        ERC721 _token = ERC721(_tokenAddress);
        return _token.isExpired(_tokenId);
    }
}