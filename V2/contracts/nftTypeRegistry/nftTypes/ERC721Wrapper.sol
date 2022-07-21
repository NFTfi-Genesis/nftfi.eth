// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../interfaces/INftWrapper.sol";

/**
 * @title ERC721Wrapper
 * @author NFTfi
 * @dev Provides logic to transfer ERC721
 */
contract ERC721Wrapper is INftWrapper {
    /**
     * @dev Transfers ERC721 `_nftId` handled by the contract `_nftContract` from `_sender` to `_recipient`
     *
     * @param _sender - The current owner of the ERC721
     * @param _recipient - The new owner of the ERC721
     * @param _nftContract - ERC721 contract
     * @param _nftId - ERC721 id
     *
     * @return true if successfully transferred, false otherwise
     */
    function transferNFT(
        address _sender,
        address _recipient,
        address _nftContract,
        uint256 _nftId
    ) external override returns (bool) {
        IERC721(_nftContract).safeTransferFrom(_sender, _recipient, _nftId);
        return true;
    }

    function isOwner(
        address _owner,
        address _nftContract,
        uint256 _tokenId
    ) external view override returns (bool) {
        return IERC721(_nftContract).ownerOf(_tokenId) == _owner;
    }

    function wrapAirdropReceiver(
        address _recipient,
        address _nftContract,
        uint256 _nftId,
        address _beneficiary
    ) external override returns (bool) {
        IERC721(_nftContract).safeTransferFrom(address(this), _recipient, _nftId, abi.encode(_beneficiary));

        return true;
    }
}
