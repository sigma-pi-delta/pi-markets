pragma solidity 0.5.0;
pragma experimental ABIEncoderV2;

import "../utils/collectable/ERC721.sol";
import "../utils/collectable/ERC721TokenReceiver.sol";
import "../utils/Owned.sol";
import "../utils/safeMath.sol";
import "../utils/collectable/SupportsInterface.sol";
import "../utils/collectable/AddressUtils.sol";

contract PiNFToken is 
    Owned,
    ERC721,
    SupportsInterface
{
    using SafeMath for uint256;
    using AddressUtils for address;

    struct JSON {
        uint key0;
        uint key1;
        uint key2;
        uint key3;
        uint key4;
        uint key5;
        uint key6;
        uint key7;
        uint key8;
        uint key9;
    }

    uint256 public globalId;
    string public jsonReference;
    string internal nftName;
    string internal nftSymbol;

    /**
    * @dev Array of all NFT IDs.
    */
    string[] public tokens;

    /**
    * List of revert message codes. Implementing dApp should handle showing the correct message.
    * Based on 0xcert framework error codes.
    */
    string constant ZERO_ADDRESS = "003001";
    string constant NOT_VALID_NFT = "003002";
    string constant NOT_OWNER_OR_OPERATOR = "003003";
    string constant NOT_OWNER_APPROWED_OR_OPERATOR = "003004";
    string constant NOT_ABLE_TO_RECEIVE_NFT = "003005";
    string constant NFT_ALREADY_EXISTS = "003006";
    string constant NOT_OWNER = "003007";
    string constant IS_OWNER = "003008";
    string constant INVALID_INDEX = "005007";

    /**
    * @dev Magic value of a smart contract that can recieve NFT.
    * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
    */
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    /**
    * @dev Mapping from token ID to its index in global tokens array.
    */
    mapping(uint256 => uint256) internal idToIndex;

    /**
    * @dev A mapping from NFT ID to the address that owns it.
    */
    mapping (uint256 => address) internal idToOwner;

    /**
    * @dev Mapping from NFT ID to approved address.
    */
    mapping (uint256 => address) internal idToApproval;

    /**
    * @dev Mapping from owner address to count of his tokens.
    */
    mapping (address => uint256) internal ownerToNFTokenCount;

    /**
    * @dev Mapping from owner address to mapping of operator addresses.
    */
    mapping (address => mapping (address => bool)) internal ownerToOperators;

    /**
    * @dev Mapping from owner to list of owned NFT IDs.
    */
    mapping(address => string[]) internal ownerToIds;

    /**
    * @dev Mapping from NFT ID to its index in the owner tokens list.
    */
    mapping(uint256 => uint256) internal idToOwnerIndex;

    mapping (uint256 => string) internal idToRef;
    mapping (bytes32 => uint256) internal refToId;
    mapping (uint256 => JSON) internal idTojson;
    mapping (uint256 => bool) public isFake;

    /**
    * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
    * @param _tokenId ID of the NFT to validate.
    */
    modifier canOperate(
        uint256 _tokenId
    )
    {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender], NOT_OWNER_OR_OPERATOR);
        _;
    }

    /**
    * @dev Guarantees that the msg.sender is allowed to transfer NFT.
    * @param _tokenId ID of the NFT to transfer.
    */
    modifier canTransfer(
        uint256 _tokenId
    )
    {
        address tokenOwner = idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender
            || idToApproval[_tokenId] == msg.sender
            || ownerToOperators[tokenOwner][msg.sender],
            NOT_OWNER_APPROWED_OR_OPERATOR
        );
        _;
    }

    /**
    * @dev Guarantees that _tokenId is a valid Token.
    * @param _tokenId ID of the NFT to validate.
    */
    modifier validNFToken(
        uint256 _tokenId
    )
    {
        require(idToOwner[_tokenId] != address(0), NOT_VALID_NFT);
        _;
    }

    constructor(
        string memory _name, 
        string memory _symbol,
        address _owner,
        string memory _jsonReference
    ) 
        public 
        Owned(_owner) 
    {
        supportedInterfaces[0x80ac58cd] = true; // ERC721
        nftName = _name;
        nftSymbol = _symbol;
        jsonReference = _jsonReference;
    }

    /************************************* */
    ////////////// CALLS
    /************************************* */

    /**
    * @dev Returns a descriptive name for a collection of NFTokens.
    * @return _name Representing name.
    */
    function name()
        external
        //override
        view
        returns (string memory _name)
    {
        _name = nftName;
    }

    /**
    * @dev Returns an abbreviated name for NFTokens.
    * @return _symbol Representing symbol.
    */
    function symbol()
        external
        //override
        view
        returns (string memory _symbol)
    {
        _symbol = nftSymbol;
    }

    /**
    * @dev Returns the count of all existing NFTokens.
    * @return Total supply of NFTs.
    */
    function totalSupply()
        external
        //override
        view
        returns (uint256)
    {
        return tokens.length;
    }

    function getTokens() external view returns(string[] memory) {
        return tokens;
    }

    function ownerOfRef(string calldata _ref) external view returns(address) {
        bytes32 _refId = keccak256(abi.encodePacked(_ref));
        return ownerOf(refToId[_refId]);
    }

    /**
    * @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
    * invalid, and queries about them do throw.
    * @param _tokenId The identifier for an NFT.
    * @return _owner Address of _tokenId owner.
    */
    function ownerOf(
        uint256 _tokenId
    )
        public
        view
        returns (address _owner)
    {
        _owner = idToOwner[_tokenId];
        require(_owner != address(0), NOT_VALID_NFT);
    }

    /**
    * @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
    * considered invalid, and this function throws for queries about the zero address.
    * @param _owner Address for whom to query the balance.
    * @return Balance of _owner.
    */
    function balanceOf(
        address _owner
    )
        external
        view
        returns (uint256)
    {
        require(_owner != address(0), ZERO_ADDRESS);
        return _getOwnerNFTCount(_owner);
    }

    /**
    * @dev Get the approved address for a single NFT.
    * @notice Throws if `_tokenId` is not a valid NFT.
    * @param _tokenId ID of the NFT to query the approval of.
    * @return Address that _tokenId is approved for.
    */
    function getApproved(
        uint256 _tokenId
    )
        external
        view
        validNFToken(_tokenId)
        returns (address)
    {
        return idToApproval[_tokenId];
    }

    /**
    * @dev Checks if `_operator` is an approved operator for `_owner`.
    * @param _owner The address that owns the NFTs.
    * @param _operator The address that acts on behalf of the owner.
    * @return True if approved for all, false otherwise.
    */
    function isApprovedForAll(
        address _owner,
        address _operator
    )
        external
        view
        returns (bool)
    {
        return ownerToOperators[_owner][_operator];
    }

    /**
    * @dev returns the n-th NFT ID from a list of owner's tokens.
    * @param _owner Token owner's address.
    * @param _index Index number representing n-th token in owner's list of tokens.
    * @return Token id.
    */
    function tokenOfOwnerByIndex(
        address _owner,
        uint256 _index
    )
        external
        view
        returns (string memory)
    {
        require(_index < ownerToIds[_owner].length, INVALID_INDEX);
        return ownerToIds[_owner][_index];
    }

    /**
    * @dev returns the n-th NFT ID from a list of owner's tokens.
    * @param _owner Token owner's address.
    * @return Token id.
    */
    function tokenOfOwner(
        address _owner
    )
        external
        view
        returns (string[] memory)
    {
        return ownerToIds[_owner];
    }

    function getIdByRef(string calldata _ref) external view returns (uint) {
        bytes32 _refId = keccak256(abi.encodePacked(_ref));
        return refToId[_refId];
    }

    function getRefById(uint256 _tokenId) external view returns (string memory) {
        return idToRef[_tokenId];
    }

    function getMetadataRef(string calldata _ref) external view returns(uint[10] memory) {
        bytes32 _refId = keccak256(abi.encodePacked(_ref));
        return getMetadata(refToId[_refId]);
    }

    function getMetadata(uint256 _tokenId) public view returns(uint[10] memory) {
        uint[10] memory _json;
        _json[0] = idTojson[_tokenId].key0;
        _json[1] = idTojson[_tokenId].key1;
        _json[2] = idTojson[_tokenId].key2;
        _json[3] = idTojson[_tokenId].key3;
        _json[4] = idTojson[_tokenId].key4;
        _json[5] = idTojson[_tokenId].key5;
        _json[6] = idTojson[_tokenId].key6;
        _json[7] = idTojson[_tokenId].key7;
        _json[8] = idTojson[_tokenId].key8;
        _json[9] = idTojson[_tokenId].key9;
        return _json;
    }

    function getTokenInfoRef(string calldata _ref) external view returns(address, uint[10] memory) {
        bytes32 _refId = keccak256(abi.encodePacked(_ref));
        return getTokenInfo(refToId[_refId]);
    }

    function getTokenInfo(uint256 _tokenId) public view returns(address, uint[10] memory) {
        address _owner = ownerOf(_tokenId);
        uint[10] memory _json = getMetadata(_tokenId);
        return (_owner, _json);
    }

    function isExpired(uint256 _tokenId) public view returns (bool) {
        uint _expiration = idTojson[_tokenId].key0;

        if (now < _expiration) {
            return false;
        } else {
            return true;
        }
    }

    /************************************* */
    ////////////// PUBLIC
    /************************************* */

    /**
    * @dev Transfers the ownership of an NFT from one address to another address. This function can
    * be changed to payable.
    * @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
    * approved address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is
    * the zero address. Throws if `_tokenId` is not a valid NFT. When transfer is complete, this
    * function checks if `_to` is a smart contract (code size > 0). If so, it calls
    * `onERC721Received` on `_to` and throws if the return value is not
    * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
    * @param _from The current owner of the NFT.
    * @param _to The new owner.
    * @param _tokenId The NFT to transfer.
    * @param _data Additional data with no specified format, sent in call to `_to`.
    */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
    {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }
    
    function safeTransferFromRef(
        address _from,
        address _to,
        string calldata _tokenRef,
        bytes calldata _data
    )
        external
    {
        bytes32 _tokenId = keccak256(abi.encodePacked(_tokenRef));
        _safeTransferFrom(_from, _to, refToId[_tokenId], _data);
    }

    /**
    * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
    * address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is the zero
    * address. Throws if `_tokenId` is not a valid NFT. This function can be changed to payable.
    * @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
    * they maybe be permanently lost.
    * @param _from The current owner of the NFT.
    * @param _to The new owner.
    * @param _tokenId The NFT to transfer.
    */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        public
        canTransfer(_tokenId)
        validNFToken(_tokenId)
    {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == _from, NOT_OWNER);
        require(_to != address(0), ZERO_ADDRESS);

        _transfer(_to, _tokenId);
    }
    
    function transferFromRef(
        address _from,
        address _to,
        string calldata _tokenRef
    )
        external
    {
        bytes32 _tokenId = keccak256(abi.encodePacked(_tokenRef));
        transferFrom(_from, _to, refToId[_tokenId]);
    }

    /**
    * @dev Set or reaffirm the approved address for an NFT. This function can be changed to payable.
    * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
    * the current NFT owner, or an authorized operator of the current owner.
    * @param _approved Address to be approved for the given NFT ID.
    * @param _tokenId ID of the token to be approved.
    */
    function approve(
        address _approved,
        uint256 _tokenId
    )
        public
        canOperate(_tokenId)
        validNFToken(_tokenId)
    {
        address tokenOwner = idToOwner[_tokenId];
        require(_approved != tokenOwner, IS_OWNER);

        idToApproval[_tokenId] = _approved;
        emit Approval(tokenOwner, _approved, _tokenId);
    }
    
    function approveRef(
        address _approved,
        string calldata _tokenRef
    )
        external
    {
        bytes32 _tokenId = keccak256(abi.encodePacked(_tokenRef));
        approve(_approved, refToId[_tokenId]);
    }

    /**
    * @dev Enables or disables approval for a third party ("operator") to manage all of
    * `msg.sender`'s assets. It also emits the ApprovalForAll event.
    * @notice This works even if sender doesn't own any tokens at the time.
    * @param _operator Address to add to the set of authorized operators.
    * @param _approved True if the operators is approved, false to revoke approval.
    */
    function setApprovalForAll(
        address _operator,
        bool _approved
    )
        external
    {
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /************************************* */
    ////////////// OWNER
    /************************************* */

    function mint(
        address _to, 
        string calldata _tokenRef, 
        uint[] calldata _json
    ) 
        onlyOwner 
        external 
    {
        bytes32 _tokenRefId = keccak256(abi.encodePacked(_tokenRef));
        uint256 _tokenId = refToId[_tokenRefId];

        if (_tokenId == 0) {
            _setRefId(_tokenRef);
            _tokenId = globalId;
            _setJson(_json, _tokenId);
        }

        _mint(_to, _tokenId);
        tokens.push(_tokenRef);
        idToIndex[_tokenId] = tokens.length - 1;
    }

    function burn(uint256 _tokenId) canTransfer(_tokenId) onlyOwner public {
        _burn(_tokenId);

        uint256 tokenIndex = idToIndex[_tokenId];
        uint256 lastTokenIndex = tokens.length - 1;
        string memory lastToken = tokens[lastTokenIndex];
        bytes32 lastTokenId = keccak256(abi.encodePacked(lastToken));

        tokens[tokenIndex] = lastToken;

        tokens.pop();
        // This wastes gas if you are burning the last token but saves a little gas if you are not.
        idToIndex[refToId[lastTokenId]] = tokenIndex;
        idToIndex[_tokenId] = 0;
    }
    
    function burnRef(string calldata _tokenRef) onlyOwner external {
        bytes32 _tokenId = keccak256(abi.encodePacked(_tokenRef));
        burn(refToId[_tokenId]);
    }

    function setFake(uint _tokenId) onlyOwner external {
        isFake[_tokenId] = true;
        emit FakeToken(_tokenId);
    }

    function setJsonReference(string memory _new) public onlyOwner {
        emit NewJsonReference(jsonReference, _new);
        jsonReference = _new;
    }

    /************************************* */
    ////////////// INTERNAL
    /************************************* */

    /**
    * @dev Actually preforms the transfer.
    * @notice Does NO checks.
    * @param _to Address of a new owner.
    * @param _tokenId The NFT that is being transferred.
    */
    function _transfer(
        address _to,
        uint256 _tokenId
    )
        internal
    {
        if (isExpired(_tokenId)) {
            _to = owner;
        }
        
        address from = idToOwner[_tokenId];
        _clearApproval(_tokenId);

        _removeNFToken(from, _tokenId);
        _addNFToken(_to, _tokenId);

        emit Transfer(from, _to, _tokenId);
    }

    /**
    * @dev Mints a new NFT.
    * @notice This is an internal function which should be called from user-implemented external
    * mint function. Its purpose is to show and properly initialize data structures when using this
    * implementation.
    * @param _to The address that will own the minted NFT.
    * @param _tokenId of the NFT to be minted by the msg.sender.
    */
    function _mint(
        address _to,
        uint256 _tokenId
    )
        internal
        //virtual
    {
        require(_to != address(0), ZERO_ADDRESS);
        require(idToOwner[_tokenId] == address(0), NFT_ALREADY_EXISTS);

        _addNFToken(_to, _tokenId);

        emit Transfer(address(0), _to, _tokenId);
    }

    /**
    * @dev Burns a NFT.
    * @notice This is an internal function which should be called from user-implemented external burn
    * function. Its purpose is to show and properly initialize data structures when using this
    * implementation. Also, note that this burn implementation allows the minter to re-mint a burned
    * NFT.
    * @param _tokenId ID of the NFT to be burned.
    */
    function _burn(
        uint256 _tokenId
    )
        internal
        //virtual
        validNFToken(_tokenId)
    {
        address tokenOwner = idToOwner[_tokenId];
        _clearApproval(_tokenId);
        _removeNFToken(tokenOwner, _tokenId);
        emit Transfer(tokenOwner, address(0), _tokenId);
    }

    /**
    * @dev Removes a NFT from owner.
    * @notice Use and //override this function with caution. Wrong usage can have serious consequences.
    * @param _from Address from wich we want to remove the NFT.
    * @param _tokenId Which NFT we want to remove.
    */
    function _removeNFToken(
        address _from,
        uint256 _tokenId
    )
        internal
        //virtual
    {
        require(idToOwner[_tokenId] == _from, NOT_OWNER);
        ownerToNFTokenCount[_from] = ownerToNFTokenCount[_from].sub(1);
        delete idToOwner[_tokenId];

        uint256 tokenToRemoveIndex = idToOwnerIndex[_tokenId];
        uint256 lastTokenIndex = ownerToIds[_from].length - 1;

        if (lastTokenIndex != tokenToRemoveIndex)
        {
            string memory lastToken = ownerToIds[_from][lastTokenIndex];
            ownerToIds[_from][tokenToRemoveIndex] = lastToken;
            bytes32 lastTokenRef = keccak256(abi.encodePacked(lastToken));
            idToOwnerIndex[refToId[lastTokenRef]] = tokenToRemoveIndex;
        }

        ownerToIds[_from].pop();
    }

    /**
    * @dev Assignes a new NFT to owner.
    * @notice Use and //override this function with caution. Wrong usage can have serious consequences.
    * @param _to Address to wich we want to add the NFT.
    * @param _tokenId Which NFT we want to add.
    */
    function _addNFToken(
        address _to,
        uint256 _tokenId
    )
        internal
        //virtual
    {
        require(idToOwner[_tokenId] == address(0), NFT_ALREADY_EXISTS);

        idToOwner[_tokenId] = _to;
        ownerToNFTokenCount[_to] = ownerToNFTokenCount[_to].add(1);

        ownerToIds[_to].push(idToRef[_tokenId]);
        idToOwnerIndex[_tokenId] = ownerToIds[_to].length - 1;
    }

    /**
    * @dev Helper function that gets NFT count of owner. This is needed for overriding in enumerable
    * extension to remove double storage (gas optimization) of owner nft count.
    * @param _owner Address for whom to query the count.
    * @return Number of _owner NFTs.
    */
    function _getOwnerNFTCount(
        address _owner
    )
        internal
        //virtual
        view
        returns (uint256)
    {
        return ownerToNFTokenCount[_owner];
    }

    /**
    * @dev Actually perform the safeTransferFrom.
    * @param _from The current owner of the NFT.
    * @param _to The new owner.
    * @param _tokenId The NFT to transfer.
    * @param _data Additional data with no specified format, sent in call to `_to`.
    */
    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    )
        private
        canTransfer(_tokenId)
        validNFToken(_tokenId)
    {
        if (isExpired(_tokenId)) {
            _to = owner;
        }
        
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == _from, NOT_OWNER);
        require(_to != address(0), ZERO_ADDRESS);

        _transfer(_to, _tokenId);

        if (_to.isContract())
        {
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(retval == MAGIC_ON_ERC721_RECEIVED, NOT_ABLE_TO_RECEIVE_NFT);
        }
    }

    /**
    * @dev Clears the current approval of a given NFT ID.
    * @param _tokenId ID of the NFT to be transferred.
    */
    function _clearApproval(
        uint256 _tokenId
    )
        private
    {
        if (idToApproval[_tokenId] != address(0))
        {
            delete idToApproval[_tokenId];
        }
    }

    function _setRefId(string memory _ref) internal {
        bytes32 _refId = keccak256(abi.encodePacked(_ref));
        globalId = globalId.add(1);
        idToRef[globalId] = _ref;
        refToId[_refId] = globalId;
    }

    function _setJson(uint[] memory _json, uint256 _tokenId) internal {
        idTojson[_tokenId].key0 = _json[0];
        idTojson[_tokenId].key1 = _json[1];
        idTojson[_tokenId].key2 = _json[2];
        idTojson[_tokenId].key3 = _json[3];
        idTojson[_tokenId].key4 = _json[4];
        idTojson[_tokenId].key5 = _json[5];
        idTojson[_tokenId].key6 = _json[6];
        idTojson[_tokenId].key7 = _json[7];
        idTojson[_tokenId].key8 = _json[8];
        idTojson[_tokenId].key9 = _json[9];

        emit NewJson(_tokenId, _json);
    }
}