pragma solidity 0.5.0;

import "../safeMath.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../tokens/utils/collectable/ERC721.sol";
import "../tokens/utils/collectable/ERC721TokenReceiver.sol";
import "../tokens/utils/packable/PNFTInterface.sol";
import "../tokens/utils/packable/PNFTokenReceiver.sol";
import "../PIBController.sol";

contract old_PIBAuction {
    using SafeMath for uint;

    struct Asset {
        address token;
        uint amountOrId;
        bytes32 tokenId; //only when packables
        uint8 category; // 1-Token, 2-NFT, 3-Packable
    }

    address payable public owner;
    address public factory;
    address public auditor;
    address public auctionToken;
    address public bidToken;
    address public maxBidder;
    uint public minValue;
    uint public endTime;
    uint public maxBid;
    bool public isOpen;
    bool public isKillable;

    PIBController public controller;
    Asset public asset;

    mapping(address => uint) public bids;

    event FundAuction(
        address indexed tokenAddress, 
        address indexed owner, 
        bytes32 tokenId,
        uint value
    );

    event Receive(
        address indexed tokenAddress, 
        address indexed _from, 
        bytes32 indexed tokenId,
        uint value
    );

    event Pay(
        address indexed tokenAddress, 
        address indexed to, 
        bytes32 indexed tokenId,
        uint value
    );

    event NewBid(address indexed bidder, uint bid);
    event UpdateBid(address indexed bidder, uint bid);
    event CancelBid(address indexed bidder);
    event PayDeal(address indexed bidder, uint bid);
    event CancelDeal(address indexed badBidder);
    event IsKillable();
    event Killed();

    modifier onlyWhenOpen() {
        require((now < endTime) && (isOpen));
        _;
    }

    modifier onlyWhenClose() {
        require(now > endTime);
        _;
    }

    constructor(
        address payable _owner,
        address _auditor,
        address[] memory _tokens, // [0] auctionToken, [1] bidToken
        uint[] memory _settings, // [0] minValue, [1] endTime
        address _controllerAddress
    ) public {
        owner = _owner;
        factory = msg.sender;
        auditor = _auditor;
        auctionToken = _tokens[0];
        bidToken = _tokens[1];
        minValue = _settings[0].mul(1 ether).div(10 ether);
        maxBid = _settings[0];
        endTime = _settings[1];
        controller = PIBController(_controllerAddress);
    }

    function () external payable {
        
    }

    function bid(uint _newBid) onlyWhenOpen public payable {
        require(_isNewBestBid(_newBid));
        _chargeToken(bidToken, msg.sender, minValue);
        emit NewBid(msg.sender, _newBid);
    }

    function updateBid(uint _newBid) onlyWhenOpen public {
        require(bids[msg.sender] != 0);
        require(_isNewBestBid(_newBid));
        emit UpdateBid(msg.sender, _newBid);
    }

    function cancelBid() public {
        require(msg.sender != maxBidder);

        _transferToken(bidToken, minValue, msg.sender);
        bids[msg.sender] = 0;
        emit CancelBid(msg.sender);
    }

    function payDeal() onlyWhenClose public payable {
        require(msg.sender == maxBidder);

        uint _amountLeft = bids[msg.sender].sub(minValue);
        _chargeToken(bidToken, msg.sender, _amountLeft);
        _transferToken(bidToken, bids[msg.sender], owner);

        if (asset.category == 1) {
            _transferToken(
                asset.token, 
                asset.amountOrId, 
                msg.sender
            );
        } else if (asset.category == 2) {
            _transferNFT(
                asset.token, 
                asset.amountOrId, 
                msg.sender
            );
        }  else if (asset.category == 3) {
            _transferPNFT(
                asset.token, 
                asset.tokenId, 
                asset.amountOrId, 
                msg.sender
            );
        }

        isKillable = true;
        emit IsKillable();

        emit PayDeal(msg.sender, bids[msg.sender]);
    }

    function cancelDeal() onlyWhenClose public {
        require(msg.sender == auditor);

        _transferToken(bidToken, minValue.div(2), owner);
        _transferToken(bidToken, minValue.div(2), msg.sender);

        if (asset.category == 1) {
            _transferToken(
                asset.token, 
                asset.amountOrId, 
                owner
            );
        } else if (asset.category == 2) {
            _transferNFT(
                asset.token, 
                asset.amountOrId, 
                owner
            );
        }  else if (asset.category == 3) {
            _transferPNFT(
                asset.token, 
                asset.tokenId, 
                asset.amountOrId, 
                owner
            );
        }

        isKillable = true;
        emit IsKillable();

        emit CancelDeal(maxBidder);
    }

    function kill() public {
        require(isKillable);
        uint _balance;

        if (bidToken == address(0)) {
            _balance = address(this).balance;
        } else {
            IRC223 _token = IRC223(bidToken);
            _balance = _token.balanceOf(address(this));
        }
        
        require(_balance == 0);

        emit Killed();
        _kill(owner);
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/
    
    /// @dev Standard ERC223 function that will handle incoming token transfers
    /// @param _from Token sender address.
    /// @param _value Amount of tokens.
    function tokenFallback(address payable _from, uint _value) public {
        require(controller.isToken(msg.sender), "088");

        _checkFallback(_from);

        asset.token = msg.sender;
        asset.amountOrId = _value;
        asset.category = 1;

        if (_from == factory) {
            emit FundAuction(msg.sender, _from, bytes32(0), _value);
        } else {
            emit Receive(msg.sender, _from, bytes32(0), _value);
        }
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

        _checkFallback(_from);

        asset.token = msg.sender;
        asset.amountOrId = _tokenId;
        asset.category = 2;

        emit FundAuction(msg.sender, _from, bytes32(0), _tokenId);
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
        
        _checkFallback(_from);

        asset.token = msg.sender;
        asset.amountOrId = _amount;
        asset.tokenId = _tokenId;
        asset.category = 3;

        emit FundAuction(msg.sender, _from, _tokenId, _amount);
        return bytes4(keccak256("onPNFTReceived(address,address,bytes32,uint256,bytes)"));
    }

    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    function _transferToken(address _tokenAddress, uint _amount, address payable _to) private {
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

        emit Pay(_tokenAddress, _to, bytes32(0), _amount);
    }

    function _transferNFT(address _tokenAddress, uint _amountOrId, address payable _to) private {
        if (controller.isNFToken(_tokenAddress)) {
            bytes memory empty;
            ERC721 _token = ERC721(_tokenAddress);
            _token.safeTransferFrom(address(this), _to, _amountOrId, empty);
        } else {
            revert();
        }

        emit Pay(_tokenAddress, _to, bytes32(0), _amountOrId);
    }

    function _transferPNFT(address _tokenAddress, bytes32 _tokenId, uint _amount, address payable _to) private {
        if (controller.isPNFToken(_tokenAddress)) {
            bytes memory empty;
            PNFTInterface _token = PNFTInterface(_tokenAddress);
            _token.safeTransferFrom(address(this), _to, _tokenId, _amount, empty);
        } else {
            revert();
        }

        emit Pay(_tokenAddress, _to, _tokenId, _amount);
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

    function _checkFallback(address _from) private {
        if (_from == owner) {
            require(!isOpen);
            require(msg.sender == auctionToken);
            isOpen = true;
        } else {
            require(msg.sender == bidToken);
        }
    }

    function _isNewBestBid(uint _newBid) private returns(bool) {
        if (_newBid > maxBid) {
            maxBid = _newBid;
            maxBidder = msg.sender;
            bids[msg.sender] = _newBid;

            return true;
        } else {
            return false;
        }
    }

    /// @dev Selfdestruct call 
    /// @param _collector Address to send left PI in the contract 
    function _kill(address payable _collector) internal {
        selfdestruct(_collector);
    }
}