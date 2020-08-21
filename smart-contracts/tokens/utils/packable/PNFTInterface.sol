pragma solidity 0.5.0;

interface PNFTInterface {
    /**
    * @dev Emits when ownership of any NFT changes by any mechanism. This event emits when NFTs are
    * created (`from` == 0) and destroyed (`to` == 0). Exception: during contract creation, any
    * number of NFTs may be created and assigned without emitting Transfer. At the time of any
    * transfer, the approved address for that NFT (if any) is reset to none.
    */
    event Transfer(
        address indexed _from,
        address indexed _to,
        bytes32 indexed _tokenId,
        uint256 _amount
    );

    /**
    * @dev This emits when the approved address for an NFT is changed or reaffirmed. The zero
    * address indicates there is no approved address. When a Transfer event emits, this also
    * indicates that the approved address for that NFT (if any) is reset to none.
    */
    event Approval(
        address indexed _owner,
        address indexed _approved,
        bytes32 indexed _tokenId,
        uint256 _amount
    );

    /**
    * @dev This emits when an operator is enabled or disabled for an owner. The operator can manage
    * all NFTs of the owner.
    */
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    event NewJson(bytes32 indexed tokenId, uint[5] json);
    event NewJsonReference(string old, string current);

    /**
    * @dev Transfers the ownership of an NFT from one address to another address.
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
        external;

    /**
    * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
    * address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is the zero
    * address. Throws if `_tokenId` is not a valid NFT.
    * @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
    * they mayb be permanently lost.
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
        external;

    function safeTransferFromApproved(
        address _from,
        address _to,
        bytes32 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external;

    /**
    * @dev Set or reaffirm the approved address for an NFT.
    * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
    * the current NFT owner, or an authorized operator of the current owner.
    * @param _approved The new approved NFT controller.
    * @param _tokenId The NFT to approve.
    */
    function approve(
        address _owner,
        address _approved,
        bytes32 _tokenId,
        uint256 _amount
    )
        external;

    /**
    * @dev Enables or disables approval for a third party ("operator") to manage all of
    * `msg.sender`'s assets. It also emits the ApprovalForAll event.
    * @notice The contract MUST allow multiple operators per owner.
    * @param _operator Address to add to the set of authorized operators.
    * @param _approved True if the operators is approved, false to revoke approval.
    */
    function setApprovalForAll(
        address _operator,
        bool _approved
    )
        external;

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
        returns (uint256);

    function balanceById(
        address _owner,
        bytes32 _tokenId
    )
        external
        view
        returns (uint256);

    /**
    * @dev Get the approved address for a single NFT.
    * @notice Throws if `_tokenId` is not a valid NFT.
    * @param _tokenId The NFT to find the approved address for.
    * @return Address that _tokenId is approved for.
    */
    function getApproved(
        address _owner,
        address _destination,
        bytes32 _tokenId
    )
        external
        view
        returns (uint256);

    /**
    * @dev Returns true if `_operator` is an approved operator for `_owner`, false otherwise.
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
        returns (bool);

    function isExpired(bytes32 _tokenId) external view returns (bool);
} 