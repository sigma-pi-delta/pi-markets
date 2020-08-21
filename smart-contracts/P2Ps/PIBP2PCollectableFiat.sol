pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../tokens/utils/collectable/ERC721.sol";
import "../tokens/utils/collectable/ERC721TokenReceiver.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "./PIBP2PReputation.sol";

contract PIBP2PCollectableFiat is ERC721TokenReceiver, ERC223ReceivingContract {
    using SafeMath for uint;

    struct Offer {
        address payable owner;
        address sellToken;
        uint sellId;
        address buyToken;
        uint buyAmount;
        bool isBuyFiat;
        uint minReputation;
        address auditor;
    }

    struct Deal {
        address sellToken;
        address buyToken;
        uint sellId;
        bool isBuyFiat;
        address payable seller;
        address payable buyer;
        uint buyAmount;
        uint8 vote1;
        uint8 vote2;
        address auditor;
    }

    PIBController public controller;
    uint public salt;
    uint public commission;
    bool public on;

    mapping(bytes32 => Offer) public offers;
    mapping(bytes32 => Deal) public deals;
    mapping(address => bool) public dealLockedUser;
    mapping(bytes32 => address) public offerFixedBuyer;

    event NewOffer(
        address indexed owner, 
        address indexed sellToken, 
        address buyToken,
        uint sellId,
        uint buyAmount,
        bool isBuyFiat,
        uint minReputation,
        address auditor,
        string description,
        bytes32 indexed offerId,
        uint[] metadata
    );

    event NewDeal(bytes32 indexed dealId, bool success, address indexed sender);

    event NewPendingDeal(
        bytes32 indexed dealId, 
        address buyer,
        uint buyAmount
    );
    
    event UpdateOffer(bytes32 indexed offerId, uint sellId, uint buyAmount);
    event CancelOffer(bytes32 indexed offerId);
    event NewCommission(uint commission);
    event DealLock(address indexed user, bool isLocked);
    event HandleDealReputation(
        address indexed seller, 
        bool isSuccess, 
        address sellTokenAddress, 
        address buyTokenAddress, 
        uint dealAmount
    );
    event VoteDeal(bytes32 indexed dealId, address sender, uint8 vote, uint8 counterpartVote);
    event AuditorNotification(bytes32 indexed dealId);
    event FixedBuyer(bytes32 offerId, address fixedBuyer);

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

    function offerFixed(
        address _sellToken, 
        uint _sellId, 
        address _buyToken, 
        uint _buyAmount,
        bool _isBuyFiat,
        uint _minReputation,
        address _auditor,
        string calldata _description,
        uint[] calldata _metadata,
        address _fixedBuyer
    ) 
        external 
        payable 
        returns (bytes32)
    {
        bytes32 _offerId = offer(_sellToken, _sellId, _buyToken, _buyAmount, _isBuyFiat, _minReputation, _auditor, _description, _metadata);
        offerFixedBuyer[_offerId] = _fixedBuyer;
        emit FixedBuyer(_offerId, _fixedBuyer);
        return _offerId;
    }

    function offer(
        address _sellToken, 
        uint _sellId, 
        address _buyToken, 
        uint _buyAmount,
        bool _isBuyFiat,
        uint _minReputation,
        address _auditor,
        string memory _description,
        uint[] memory _metadata
    ) 
        public 
        payable 
        returns (bytes32)
    {
        require(controller.isToken(_buyToken), "062");
        require(controller.isNFToken(_sellToken), "063");

        _chargeToken(_sellToken, msg.sender, _sellId);
        
        return _newOffer(
            _sellToken,
            _sellId,
            _buyToken,
            _buyAmount,
            _isBuyFiat,
            _minReputation,
            _auditor,
            _description,
            _metadata
        );
    }

    function deal(bytes32 _offerId) external payable returns (bytes32) {
        require(!_isNFTExpired(offers[_offerId].sellToken, offers[_offerId].sellId));
        PIBP2PReputation _p2pReputation = PIBP2PReputation(controller.addresses(16));
        require(offers[_offerId].minReputation <= _p2pReputation.offchainReputation(msg.sender), "047");

        if (offerFixedBuyer[_offerId] != address(0)) {
            require(msg.sender == offerFixedBuyer[_offerId], "097");
        }

        if (!offers[_offerId].isBuyFiat) {
            _chargeToken(offers[_offerId].buyToken, msg.sender, offers[_offerId].buyAmount);
        } else {
            require(!dealLockedUser[msg.sender], "048");
            dealLockedUser[msg.sender] = true;
            emit DealLock(msg.sender, true);
        }

        uint _buyAmount = offers[_offerId].buyAmount;
        uint _sellId = offers[_offerId].sellId;
        address _sellToken = offers[_offerId].sellToken;
        address _buyToken = offers[_offerId].buyToken;
        address payable _seller = offers[_offerId].owner;

        _setPendingDeal(
            _offerId, 
            msg.sender
        );

        emit NewPendingDeal(_offerId, msg.sender, _buyAmount);

        _updateOffer(_offerId, 0, 0); //0,0 is to close the offer

        if (!deals[_offerId].isBuyFiat) {
            _settleDeal(
                _offerId, 
                true
            );
        }
    }

    function voteDeal(bytes32 _dealId, uint8 _vote) external {
        require((_vote == 1) || (_vote == 2), "050");

        uint8 _counterpartVote;

        if (msg.sender == deals[_dealId].seller) {
            deals[_dealId].vote1 = _vote;
            _counterpartVote = deals[_dealId].vote2;
        } else if (msg.sender == deals[_dealId].buyer) {
            deals[_dealId].vote2 = _vote;
            _counterpartVote = deals[_dealId].vote1;
        } else {
            revert();
        }

        emit VoteDeal(_dealId, msg.sender, _vote, _counterpartVote);

        _checkDeal(_dealId);
    }

    function requestAuditor(bytes32 _dealId) external {
        require((msg.sender == deals[_dealId].seller) || (msg.sender == deals[_dealId].buyer), "051");
        _requestAuditor(_dealId);
    }

    function voteDealAuditor(bytes32 _dealId, bool _success) external {
        require(msg.sender == deals[_dealId].auditor, "052");

        _settleDeal(_dealId, _success);
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
        bool _isBuyFiat,
        uint _minReputation,
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
        offers[_offerId].isBuyFiat = _isBuyFiat;
        offers[_offerId].minReputation = _minReputation;
        offers[_offerId].auditor = _auditor;

        emit NewOffer(
            msg.sender,
            _sellToken,
            _buyToken,
            _sellId,
            _buyAmount,
            _isBuyFiat,
            _minReputation,
            _auditor,
            _description,
            _offerId,
            _metadata
        );

        return _offerId;
    }

    function _setPendingDeal(
        bytes32 _offerId,
        address payable _buyer
    )
        private
    {
        require(offers[_offerId].owner != _buyer, "057");

        deals[_offerId].sellToken = offers[_offerId].sellToken;
        deals[_offerId].buyToken = offers[_offerId].buyToken;
        deals[_offerId].sellId = offers[_offerId].sellId;
        deals[_offerId].isBuyFiat = offers[_offerId].isBuyFiat;
        deals[_offerId].seller = offers[_offerId].owner;
        deals[_offerId].buyer = _buyer;
        deals[_offerId].buyAmount = offers[_offerId].buyAmount;
        deals[_offerId].auditor = offers[_offerId].auditor;
    }

    function _checkDeal(bytes32 _dealId) private {
        if ((deals[_dealId].vote1 != 0) && (deals[_dealId].vote2 != 0)) {
            if ((deals[_dealId].vote1 == 1) && (deals[_dealId].vote2 == 1)) {
                _settleDeal(_dealId, true);
            } else if ((deals[_dealId].vote1 == 2) && (deals[_dealId].vote2 == 2)) {
                _settleDeal(_dealId, false);
            } else {
                _requestAuditor(_dealId);
            }
        }
    }

    function _settleDeal(
        bytes32 _dealId, 
        bool _success
    ) 
        private 
    {
        _checkReputation(_dealId, _success);
        
        if (deals[_dealId].isBuyFiat) {
            dealLockedUser[deals[_dealId].buyer] = false;
            emit DealLock(deals[_dealId].buyer, false);
        }
        
        if (_success) {
            _finishDeal(_dealId);
        } else {
            _cancelDeal(_dealId);
        }

        emit NewDeal(_dealId, _success, msg.sender);
    }

    function _finishDeal(bytes32 _dealId) private {
        address _buyToken = deals[_dealId].buyToken;
        address _sellToken = deals[_dealId].sellToken;
        uint _sellId = deals[_dealId].sellId;
        uint _buyAmount = deals[_dealId].buyAmount;
        address payable _seller = deals[_dealId].seller;
        address payable _buyer = deals[_dealId].buyer;
        bool _isBuyFiat = deals[_dealId].isBuyFiat;
        uint _commission = _buyAmount.mul(commission).div(100 ether);
        address payable _collector = address(uint160(controller.addresses(7))); //Collector
        uint _sellerAmount = _buyAmount.sub(_commission);

        delete deals[_dealId];

        if (!_isBuyFiat) {
            _transfer(_buyToken, _commission, _collector);
            _transfer(_buyToken, _sellerAmount, _seller);
        }

        _transfer(_sellToken, _sellId, _buyer);
    }

    function _cancelDeal(bytes32 _dealId) private {
        address _sellToken = deals[_dealId].sellToken;
        address _buyToken = deals[_dealId].buyToken;
        uint _buyAmount = deals[_dealId].buyAmount;
        uint _sellId = deals[_dealId].sellId;
        address payable _seller = deals[_dealId].seller;
        address payable _buyer = deals[_dealId].buyer;
        bool _isBuyFiat = deals[_dealId].isBuyFiat;

        delete deals[_dealId];

        _transfer(_sellToken, _sellId, _seller);

        if (!_isBuyFiat) {
            _transfer(_buyToken, _buyAmount, _buyer);
        }
    }

    function _checkReputation(bytes32 _dealId, bool _success) private {
        if (deals[_dealId].isBuyFiat) {
            if (msg.sender == deals[_dealId].auditor) {
                if (_success) {
                    if (deals[_dealId].vote1 != 1) {
                        emit HandleDealReputation(
                            deals[_dealId].seller, 
                            false, 
                            deals[_dealId].sellToken,
                            deals[_dealId].buyToken, 
                            deals[_dealId].buyAmount
                        );
                    } else {
                        emit HandleDealReputation(
                            deals[_dealId].seller, 
                            true, 
                            deals[_dealId].sellToken, 
                            deals[_dealId].buyToken, 
                            deals[_dealId].buyAmount
                        );
                    }
                }
            } else if (_success) {
                emit HandleDealReputation(
                    deals[_dealId].seller, 
                    true, 
                    deals[_dealId].sellToken, 
                    deals[_dealId].buyToken, 
                    deals[_dealId].buyAmount
                );
            }
        }
    }

    function _requestAuditor(bytes32 _dealId) private {
        emit AuditorNotification(_dealId);
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