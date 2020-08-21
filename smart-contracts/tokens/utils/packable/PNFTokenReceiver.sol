pragma solidity 0.5.0;

/**
 * @dev ERC-721 interface for accepting safe transfers.
 * See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
 */
interface PNFTokenReceiver
{

    /**
    * @dev Handle the receipt of a NFT. The ERC721 smart contract calls this function on the
    * recipient after a `transfer`. This function MAY throw to revert and reject the transfer. Return
    * of other than the magic value MUST result in the transaction being reverted.
    * Returns `bytes4(keccak256("onPNFTReceived(address,address,uint256,uint256,bytes)"))` unless throwing.
    * @notice The contract address is always the message sender. A wallet/broker/auction application
    * MUST implement the wallet interface if it will accept safe transfers.
    * @param _operator The address which called `safeTransferFrom` function.
    * @param _from The address which previously owned the token.
    * @param _tokenId The NFT identifier which is being transferred.
    * @param _data Additional data with no specified format.
    * @return Returns `bytes4(keccak256("onPNFTReceived(address,address,uint256,uint256,bytes)"))`.
    */
    function onPNFTReceived(
        address _operator,
        address _from,
        bytes32 _tokenId,
        uint256 _amount,
        bytes calldata _data
    )
        external
        returns(bytes4);

}
