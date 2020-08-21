pragma solidity 0.5.0;
pragma experimental ABIEncoderV2;

import "../utils/packable/PNFTInterface.sol";
import "../utils/packable/PNFTokenReceiver.sol";
import "../utils/Owned.sol";
import "../utils/safeMath.sol";
import "../utils/packable/AddressUtils.sol";

contract PiPNFToken is 
    Owned,
    PNFTInterface
{
    using SafeMath for uint256;
    using AddressUtils for address;

    struct JSON {
        uint key0;
        uint key1;
        uint key2;
        uint key3;
        uint key4;
    }

    string public jsonReference;
    string internal nftName;
    string internal nftSymbol;
    uint8 internal _decimals;

    bytes32[] public tokens;

    /**
    * @dev Magic value of a smart contract that can recieve PNFT.
    * Equal to: bytes4(keccak256("onPNFTReceived(address,address,bytes32,uint256,bytes)")).
    */
    bytes4 internal constant MAGIC_ON_PNFT_RECEIVED = 0x82cf5afa;

    mapping(bytes32 => uint256) internal idToIndex; //id:index_in_tokens_array
    mapping (address => mapping (address => mapping (bytes32 => uint256))) internal approvals; //owner:approved:id:amount
    mapping (address => uint256) internal ownerToNFTokenCount; //owner:count
    mapping (address => mapping (address => bool)) internal ownerToOperators; //owner:operator:isOperator
    mapping(address => bytes32[]) internal ownerToIds; //owner:ids_array_in_balance
    mapping(address => mapping(bytes32 => uint256)) internal idToOwnerIndex; //ower:id:index_in_owner_array
    mapping(address => mapping(bytes32 => uint256)) public balances; //holder:category:balance
    mapping(bytes32 => uint256) public supplyByCategory; //category:totalSupply
    mapping (bytes32 => JSON) internal idTojson;

    modifier canOperate(
        address _owner,
        bytes32 _tokenId,
        uint256 _amount
    )
    {
        require((msg.sender == _owner && balances[msg.sender][_tokenId] >= _amount) 
        || (ownerToOperators[_owner][msg.sender] && balances[_owner][_tokenId] >= _amount), "124");
        _;
    }

    modifier isApproved(
        address _owner,
        address _to,
        bytes32 _tokenId,
        uint256 _amount
    )
    {
        uint256 _approvedAmount = approvals[_owner][_to][_tokenId];
        require(
            balances[_owner][_tokenId] >= _amount
            || _approvedAmount >= _amount, "125"
        );
        _;
    }

    modifier validNFToken(
        bytes32 _tokenId
    )
    {
        require(supplyByCategory[_tokenId] > 0, "126");
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
        nftName = _name;
        nftSymbol = _symbol;
        _decimals = 18;
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
        view
        returns (string memory _symbol)
    {
        _symbol = nftSymbol;
    }

    function decimals() external view returns (uint8){
        return _decimals;
    }

    /**
    * @dev Returns the count of all existing NFTokens.
    * @return Total supply of NFTs.
    */
    function totalSupply()
        external
        view
        returns (uint256)
    {
        return tokens.length;
    }

    function getTokens() external view returns(bytes32[] memory) {
        return tokens;
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
        require(_owner != address(0));
        return _getOwnerNFTCount(_owner);
    }

    function balanceById(
        address _owner,
        bytes32 _tokenId
    )
        external
        view
        returns (uint256)
    {
        require(_owner != address(0), "127");
        return balances[_owner][_tokenId];
    }

    /**
    * @dev Get the approved address for a single NFT.
    * @notice Throws if `_tokenId` is not a valid NFT.
    * @param _tokenId ID of the NFT to query the approval of.
    * @return Address that _tokenId is approved for.
    */
    function getApproved(
        address _owner,
        address _destination,
        bytes32 _tokenId
    )
        external
        view
        returns (uint256)
    {
        return approvals[_owner][_destination][_tokenId];
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
        returns (bytes32)
    {
        require(_index < ownerToIds[_owner].length, "128");
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
        returns (bytes32[] memory)
    {
        return ownerToIds[_owner];
    }

    function getMetadata(bytes32 _tokenId) public view returns(uint[5] memory) {
        uint[5] memory _json;
        _json[0] = idTojson[_tokenId].key0;
        _json[1] = idTojson[_tokenId].key1;
        _json[2] = idTojson[_tokenId].key2;
        _json[3] = idTojson[_tokenId].key3;
        _json[4] = idTojson[_tokenId].key4;
        return _json;
    }

    function isExpired(bytes32 _tokenId) public view returns (bool) {
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
        bytes32 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external
        canOperate(_from, _tokenId, _amount)
    {
        _safeTransferFrom(_from, _to, _tokenId, _amount, _data);
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
        bytes32 _tokenId,
        uint256 _amount
    )
        public
        canOperate(_from, _tokenId, _amount)
        validNFToken(_tokenId)
    {
        require(balances[_from][_tokenId] >= _amount, "129");
        require(_to != address(0), "130");

        _transfer(_from, _to, _tokenId, _amount);
    }

    function safeTransferFromApproved(
        address _from,
        address _to,
        bytes32 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external
        isApproved(_from, _to, _tokenId, _amount)
    {
        approvals[_from][_to][_tokenId] = approvals[_from][_to][_tokenId].sub(_amount);
        _safeTransferFrom(_from, _to, _tokenId, _amount, _data);
    }

    /**
    * @dev Set or reaffirm the approved address for an NFT. This function can be changed to payable.
    * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
    * the current NFT owner, or an authorized operator of the current owner.
    * @param _approved Address to be approved for the given NFT ID.
    * @param _tokenId ID of the token to be approved.
    */
    function approve(
        address _owner,
        address _approved,
        bytes32 _tokenId,
        uint256 _amount
    )
        public
        canOperate(_owner, _tokenId, _amount)
        validNFToken(_tokenId)
    {
        require(_approved != _owner, "131");

        approvals[_owner][_approved][_tokenId] = _amount;
        emit Approval(_owner, _approved, _tokenId, _amount);
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
        uint[5] calldata _json,
        uint256 _amount
    ) 
        onlyOwner 
        external 
    {
        bytes32 _tokenId = keccak256(abi.encodePacked(
            _json[0],
            _json[1],
            _json[2],
            _json[3],
            _json[4]
        ));
        
        if (supplyByCategory[_tokenId] == 0) {
            tokens.push(_tokenId);
            idToIndex[_tokenId] = tokens.length - 1;
            _setJson(_json, _tokenId);
        }

        _mint(_to, _tokenId, _amount);
        supplyByCategory[_tokenId] = supplyByCategory[_tokenId].add(_amount);
    }

    function burn(bytes32 _tokenId, uint256 _amount) canOperate(msg.sender, _tokenId, _amount) onlyOwner public {
        _burn(msg.sender, _tokenId, _amount);
        supplyByCategory[_tokenId] = supplyByCategory[_tokenId].sub(_amount);

        if (supplyByCategory[_tokenId] == 0) {
            uint256 tokenIndex = idToIndex[_tokenId];
            uint256 lastTokenIndex = tokens.length - 1;
            bytes32 lastToken = tokens[lastTokenIndex];

            tokens[tokenIndex] = lastToken;

            tokens.pop();
            // This wastes gas if you are burning the last token but saves a little gas if you are not.
            idToIndex[lastToken] = tokenIndex;
            idToIndex[_tokenId] = 0;
        }
    }

    function setJsonReference(string memory _new) public onlyOwner {
        emit NewJsonReference(jsonReference, _new);
        jsonReference = _new;
    }

    /************************************* */
    ////////////// INTERNAL
    /************************************* */

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
        bytes32 _tokenId,
        uint256 _amount,
        bytes memory _data
    )
        private
        validNFToken(_tokenId)
    {
        require(balances[_from][_tokenId] >= _amount, "132");
        require(_to != address(0), "133");
        
        if (isExpired(_tokenId)) {
            _to = owner;
        }

        _transfer(_from, _to, _tokenId, _amount);

        if (_to.isContract())
        {
            bytes4 retval = PNFTokenReceiver(_to).onPNFTReceived(msg.sender, _from, _tokenId, _amount, _data);
            require(retval == MAGIC_ON_PNFT_RECEIVED, "134");
        }
    }

    /**
    * @dev Actually preforms the transfer.
    * @notice Does NO checks.
    * @param _to Address of a new owner.
    * @param _tokenId The NFT that is being transferred.
    */
    function _transfer(
        address _from,
        address _to,
        bytes32 _tokenId,
        uint256 _amount
    )
        internal
    {
        if (isExpired(_tokenId)) {
            _to = owner;
        }
        
        uint _entireAmount = _amount.div(1 ether).mul(1 ether);
        require(_amount == _entireAmount, "135");
        _decreaseBalance(_from, _tokenId, _entireAmount);
        _increaseBalance(_to, _tokenId, _entireAmount);

        emit Transfer(_from, _to, _tokenId, _entireAmount);
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
        bytes32 _tokenId,
        uint256 _amount
    )
        internal
    {
        require(_to != address(0), "136");
        uint _entireAmount = _amount.div(1 ether).mul(1 ether);
        require(_amount == _entireAmount, "137");

        _increaseBalance(_to, _tokenId, _amount);

        emit Transfer(address(0), _to, _tokenId, _amount);
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
        address _from,
        bytes32 _tokenId,
        uint256 _amount
    )
        internal
        validNFToken(_tokenId)
    {
        uint _entireAmount = _amount.div(1 ether).mul(1 ether);
        require(_amount == _entireAmount, "138");
        _decreaseBalance(_from, _tokenId, _amount);
        emit Transfer(_from, address(0), _tokenId, _amount);
    }

    function _increaseBalance(address _who, bytes32 _tokenId, uint256 _amount) private {
        if (balances[_who][_tokenId] == 0) {
            _addNFToken(_who, _tokenId);
        }

        balances[_who][_tokenId] = balances[_who][_tokenId].add(_amount);
    }

    function _decreaseBalance(address _who, bytes32 _tokenId, uint256 _amount) private {
        require(balances[_who][_tokenId] >= _amount, "139");

        balances[_who][_tokenId] = balances[_who][_tokenId].sub(_amount);

        if (balances[_who][_tokenId] == 0) {
            _removeNFToken(_who, _tokenId);
        }
    }

    /**
    * @dev Removes a NFT from owner.
    * @notice Use and //override this function with caution. Wrong usage can have serious consequences.
    * @param _from Address from wich we want to remove the NFT.
    * @param _tokenId Which NFT we want to remove.
    */
    function _removeNFToken(
        address _from,
        bytes32 _tokenId
    )
        internal
    {
        ownerToNFTokenCount[_from] = ownerToNFTokenCount[_from].sub(1);

        uint256 tokenToRemoveIndex = idToOwnerIndex[_from][_tokenId];
        uint256 lastTokenIndex = ownerToIds[_from].length - 1;

        if (lastTokenIndex != tokenToRemoveIndex)
        {
            bytes32 lastToken = ownerToIds[_from][lastTokenIndex];
            ownerToIds[_from][tokenToRemoveIndex] = lastToken;
            idToOwnerIndex[_from][_tokenId] = tokenToRemoveIndex;
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
        bytes32 _tokenId
    )
        internal
    {
        ownerToNFTokenCount[_to] = ownerToNFTokenCount[_to].add(1);
        ownerToIds[_to].push(_tokenId);
        idToOwnerIndex[_to][_tokenId] = ownerToIds[_to].length - 1;
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
        view
        returns (uint256)
    {
        return ownerToNFTokenCount[_owner];
    }

    function _setJson(uint[5] memory _json, bytes32 _tokenId) internal {
        idTojson[_tokenId].key0 = _json[0];
        idTojson[_tokenId].key1 = _json[1];
        idTojson[_tokenId].key2 = _json[2];
        idTojson[_tokenId].key3 = _json[3];
        idTojson[_tokenId].key4 = _json[4];

        emit NewJson(_tokenId, _json);
    }
}