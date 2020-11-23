pragma solidity 0.5.0;

import "../safeMath.sol";
import "../tokens/utils/fiat/IRC223.sol";
import "../tokens/utils/fiat/ERC223_receiving_contract.sol";
import "../tokens/utils/collectable/ERC721.sol";
import "../tokens/utils/collectable/ERC721TokenReceiver.sol";
import "../tokens/utils/packable/PNFTInterface.sol";
import "../tokens/utils/packable/PNFTokenReceiver.sol";
import "../PIBController.sol";
import "../PIBWalletDiamond/PIBWalletInterface.sol";
import "../PIBRegistry.sol";
import "./PIBAuctionDiamond.sol";
import "./IDiamondFacet.sol";

contract PIBAuctionFactory {
    PIBController public controller;
    bool public cuttable;
    uint public commission;
    
    mapping(bytes4 => address) public facets;

    event NewAuction(
        address indexed newAuction,
        address indexed owner,
        address[] tokens,
        uint auctionAmountOrId,
        bytes32 auctionTokenId,
        address auditor,
        uint[] settings
    );

    event DiamondCut(
        bytes4 indexed selector, 
        address indexed oldFacet, 
        address indexed newFacet
    );

    constructor(address _controllerAddress, address[] memory _facets) public {
        controller = PIBController(_controllerAddress);
        cuttable = true;
        commission = 1 ether;
        _diamondCut(_facets);
    }

    function deployAuction(
        address _auditor,
        address[] calldata _tokens, // [0] auctionToken, [1] bidToken
        uint _auctionAmountOrId,
        bytes32 _auctionTokenId,
        uint[] calldata _settings // [0] minValue, [1] endTime
    ) 
        external 
        payable 
        returns(address) 
    {
        require(isSmartID(msg.sender));
        require(controller.isToken(_tokens[1]));
        PIBAuctionDiamond _newAuction = new PIBAuctionDiamond(
            msg.sender,
            _auditor,
            _tokens,
            _settings,
            commission,
            address(controller)
        );

        if (controller.isToken(_tokens[0])) {
            _chargeToken(_tokens[0], msg.sender, _auctionAmountOrId);
            _transferToken(_tokens[0], _auctionAmountOrId, address(uint160(address(_newAuction))));
        } else if (controller.isNFToken(_tokens[0])){
            _chargeNFToken(_tokens[0], msg.sender, _auctionAmountOrId);
            _transferNFT(_tokens[0], _auctionAmountOrId, address(uint160(address(_newAuction))));
        } else if (controller.isPNFToken(_tokens[0])){
            _chargePNFToken(_tokens[0], msg.sender, _auctionTokenId, _auctionAmountOrId);
            _transferPNFT(_tokens[0], _auctionTokenId, _auctionAmountOrId, address(uint160(address(_newAuction))));
        }

        emit NewAuction(
            address(_newAuction), 
            msg.sender, 
            _tokens, 
            _auctionAmountOrId,
            _auctionTokenId,
            _auditor,
            _settings
        );

        return address(_newAuction);
    }

    function setCommission(uint _newCommission) public {
        require(msg.sender == controller.owner());
        commission = _newCommission;
    }

    function stopCuts() external {
        require(msg.sender == controller.owner());
        cuttable = false;
    }

    function diamondCut(address[] calldata _addresses) external {
        require(msg.sender == controller.owner());
        _diamondCut(_addresses);
    }

    function _diamondCut(address[] memory _addresses) internal {

        for (uint i = 0; i < _addresses.length; i++) {
            IDiamondFacet _facet = IDiamondFacet(_addresses[i]);
            bytes4[] memory _selectors = _facet.getSelectors();

            for (uint j = 0; j < _selectors.length; j++) {
                if (facets[_selectors[j]] != address(0)) {
                    require(cuttable, "Not cuttable");
                }

                emit DiamondCut(_selectors[j], facets[_selectors[j]], _addresses[i]);

                facets[_selectors[j]] = _addresses[i];
            }
        }
    }

    /***************************************************************/
    // PUBLIC FUNCTIONS
    /***************************************************************/
    
    /// @dev Standard ERC223 function that will handle incoming token transfers
    /// @param _from Token sender address.
    /// @param _value Amount of tokens.
    function tokenFallback(address payable _from, uint _value) public {
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
        return bytes4(keccak256("onPNFTReceived(address,address,bytes32,uint256,bytes)"));
    }

    function isSmartID(address _wallet) public view returns (bool) {
        PIBWalletInterface _walletContract = PIBWalletInterface(_wallet);
        address _identity = _walletContract.owner();
        PIBRegistry _registry = PIBRegistry(address(uint160(controller.addresses(1))));
        return _registry.hashesDD(_identity) != bytes32(0);
    }

    /***************************************************************/
    // PRIVATE FUNCTIONS
    /***************************************************************/

    function _transferToken(address _tokenAddress, uint _amount, address payable _to) private {
        if (controller.isToken(_tokenAddress)) {
            if (_tokenAddress == address(0)) {
                //_to.transfer(_amount);
                (bool _success, bytes memory _result) = _to.call.value(_amount)(abi.encode(bytes4(keccak256("piFallback()"))));

                if (!_success) {
                    revert();
                }
            } else {
                IRC223 _token = IRC223(_tokenAddress);
                _token.transfer(_to, _amount);
            }
        } else {
            revert();
        }      
    }

    function _transferNFT(address _tokenAddress, uint _amountOrId, address payable _to) private {
        if (controller.isNFToken(_tokenAddress)) {
            bytes memory empty;
            ERC721 _token = ERC721(_tokenAddress);
            _token.safeTransferFrom(address(this), _to, _amountOrId, empty);
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

    function _chargeNFToken(address _tokenAddress, address payable _from, uint _amountOrId) private {
        if (controller.isNFToken(_tokenAddress)) {
            require(!_isNFTExpired(_tokenAddress, _amountOrId), "141");
            bytes memory empty;
            ERC721 _token = ERC721(_tokenAddress);
            _token.safeTransferFrom(_from, address(this), _amountOrId, empty);
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

    function _isNFTExpired(address _tokenAddress, uint _tokenId) internal view returns(bool) {
        ERC721 _token = ERC721(_tokenAddress);
        return _token.isExpired(_tokenId);
    }
}