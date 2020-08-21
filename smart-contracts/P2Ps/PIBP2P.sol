pragma solidity 0.5.0;

import "../safeMath.sol";
import "../PIBController.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../native-tokens/TDNPriceOracleInterface.sol";
import "./PIBP2PReputation.sol";

contract PIBP2P is ERC223ReceivingContract {
    using SafeMath for uint;

    struct Offer {
        address payable owner;
        address sellToken;
        uint sellAmount;
        uint commission;
        bool isPartial;
        address buyToken;
        uint buyAmount;
        bool isBuyFiat;
        uint minDealAmount;
        uint maxDealAmount;
        uint minReputation;
        address auditor;
    }

    struct Deal {
        address sellToken;
        address buyToken;
        bool isBuyFiat;
        address payable seller;
        address payable buyer;
        uint buyAmount;
        uint sellAmount;
        uint commission;
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
    mapping(address => bool) public isTDN;
    mapping(address => mapping(address => address)) public priceOracle;
    mapping(bytes32 => address) public offerFixedBuyer;

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
    event VoteDeal(bytes32 indexed dealId, address sender, uint8 vote, uint8 counterpartVote);
    event AuditorNotification(bytes32 indexed dealId);
    event UpdateReputation(address user, uint reputation);
    event HandleDealReputation(address indexed seller, bool isSuccess, address tokenAddress, uint dealAmount);
    event DealLock(address indexed user, bool isLocked);
    event NewCommission(uint commission);
    event FixedBuyer(bytes32 offerId, address fixedBuyer);

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

    function setCommission(uint _newCommission) public onlyOwner isOn {
        commission = _newCommission;

        emit NewCommission(commission);
    }

    function setTDN(address _token, bool _isTDN) public onlyOwner isOn {
        isTDN[_token] = _isTDN;
    }

    function setPriceOracle(address _token1, address _token2, address _oracle) public onlyOwner isOn {
        priceOracle[_token1][_token2] = _oracle;
        priceOracle[_token2][_token1] = _oracle;
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
        PIBP2PReputation _p2pReputation = PIBP2PReputation(controller.addresses(16));
        require(offers[_offerId].minReputation <= _p2pReputation.offchainReputation(msg.sender), "047");

        if (offerFixedBuyer[_offerId] != address(0)) {
            require(msg.sender == offerFixedBuyer[_offerId], "097");
        }

        uint _sellAmount;
        uint _offerSellAmount;
        uint _offerBuyAmount;
        uint _dealCommission;
        uint _offerCommission;

        if (!offers[_offerId].isBuyFiat) {
            _chargeToken(offers[_offerId].buyToken, msg.sender, _buyAmount);
        } else {
            require(!dealLockedUser[msg.sender], "048");
            dealLockedUser[msg.sender] = true;
            emit DealLock(msg.sender, true);
        }

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

        bytes32 _dealId = _setPendingDeal(
            _offerId, 
            offers[_offerId].owner, 
            msg.sender, 
            _buyAmount, 
            _sellAmount,
            _dealCommission
        );

        emit NewPendingDeal(_offerId, _dealId, msg.sender, _sellAmount, _buyAmount);

        _updateOffer(_offerId, _offerSellAmount, _offerBuyAmount, _offerCommission);

        if (!deals[_dealId].isBuyFiat) {
            _settleDeal(_dealId, true);
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

    function updateReputationArray(address[] calldata _users, uint[] calldata _reputations) external {
        require(_users.length == _reputations.length);
        for (uint i = 0; i < _users.length; i++) {
            updateReputation(_users[i], _reputations[i]);
        }
    }

    function updateReputation(address _user, uint _reputation) public onlyBackend {
        PIBP2PReputation _p2pReputation = PIBP2PReputation(controller.addresses(16));
        _p2pReputation.updateReputation(_user, _reputation);

        emit UpdateReputation(_user, _reputation);
    }
    
    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "056");
    }

    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    function _setPendingDeal(
        bytes32 _offerId,
        address payable _seller,
        address payable _buyer,
        uint _buyAmount,
        uint _sellAmount,
        uint _commission
    )
        private
        returns (bytes32)
    {
        require(_seller != _buyer, "057");
        bytes32 _dealId = bytes32(
            keccak256(
                abi.encodePacked(
                    _offerId,
                    _seller, 
                    _buyer,
                    _buyAmount,
                    _sellAmount,
                    salt++
                )
            )
        );

        deals[_dealId].sellToken = offers[_offerId].sellToken;
        deals[_dealId].buyToken = offers[_offerId].buyToken;
        deals[_dealId].isBuyFiat = offers[_offerId].isBuyFiat;
        deals[_dealId].seller = _seller;
        deals[_dealId].buyer = _buyer;
        deals[_dealId].buyAmount = _buyAmount;
        deals[_dealId].sellAmount = _sellAmount;
        deals[_dealId].commission = _commission;
        deals[_dealId].auditor = offers[_offerId].auditor;

        return _dealId;
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

    function _requestAuditor(bytes32 _dealId) private {
        emit AuditorNotification(_dealId);
    }

    function _settleDeal(bytes32 _dealId, bool _success) private {
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

    function _checkReputation(bytes32 _dealId, bool _success) private {
        if (deals[_dealId].isBuyFiat) {
            if (msg.sender == deals[_dealId].auditor) {
                if (_success) {
                    if (deals[_dealId].vote1 != 1) {
                        emit HandleDealReputation(
                            deals[_dealId].seller, 
                            false, 
                            deals[_dealId].sellToken, 
                            deals[_dealId].sellAmount
                        );
                    } else {
                        emit HandleDealReputation(
                            deals[_dealId].seller, 
                            true, 
                            deals[_dealId].sellToken, 
                            deals[_dealId].sellAmount
                        );
                    }
                }
            } else if (_success) {
                emit HandleDealReputation(
                    deals[_dealId].seller, 
                    true, 
                    deals[_dealId].sellToken, 
                    deals[_dealId].sellAmount
                );
            }
        }
    }

    function _finishDeal(bytes32 _dealId) private {
        address _buyToken = deals[_dealId].buyToken;
        address _sellToken = deals[_dealId].sellToken;
        uint _buyAmount = deals[_dealId].buyAmount;
        uint _sellAmount = deals[_dealId].sellAmount;
        uint _commission = deals[_dealId].commission;
        address payable _seller = deals[_dealId].seller;
        address payable _buyer = deals[_dealId].buyer;
        bool _isBuyFiat = deals[_dealId].isBuyFiat;

        delete deals[_dealId];

        if (!_isBuyFiat) {
            _transfer(_buyToken, _buyAmount, _seller);
        }

        _transfer(_sellToken, _sellAmount, _buyer);
        address payable _collector = address(uint160(controller.addresses(7))); //Collector
        _transfer(_sellToken, _commission, _collector);

        _votePriceOracle(_sellToken, _buyToken, _sellAmount, _buyAmount, _seller);
    }

    function _cancelDeal(bytes32 _dealId) private {
        address _sellToken = deals[_dealId].sellToken;
        address _buyToken = deals[_dealId].buyToken;
        uint _buyAmount = deals[_dealId].buyAmount;
        uint _sellAmount = deals[_dealId].sellAmount;
        uint _commission = deals[_dealId].commission;
        address payable _seller = deals[_dealId].seller;
        address payable _buyer = deals[_dealId].buyer;
        bool _isBuyFiat = deals[_dealId].isBuyFiat;

        delete deals[_dealId];

        _transfer(_sellToken, _sellAmount.add(_commission), _seller);

        if (!_isBuyFiat) {
            _transfer(_buyToken, _buyAmount, _buyer);
        }
    }

    function _votePriceOracle(
        address _token1, 
        address _token2, 
        uint _amount1, 
        uint _amount2,
        address _marketMaker
    ) 
        private 
    {
        address _oracle = priceOracle[_token1][_token2];
        uint _price;
        uint _ponderation;

        if (_oracle != address(0)) {
            if (isTDN[_token1]) {
                _price = _amount1.mul(1 ether).div(_amount2);
                _ponderation = _amount1;
            } else {
                _price = _amount2.mul(1 ether).div(_amount1);
                _ponderation = _amount2;
            }

            TDNPriceOracleInterface _priceOracle = TDNPriceOracleInterface(_oracle);
            _priceOracle.votePrice(_price, _ponderation, _marketMaker);
        }
    }

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
        offers[_offerId].isBuyFiat = _settings[1];
        offers[_offerId].minDealAmount = _limits[0];
        offers[_offerId].maxDealAmount = _limits[1];
        offers[_offerId].minReputation = _limits[2];
        offers[_offerId].auditor = _auditor;

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