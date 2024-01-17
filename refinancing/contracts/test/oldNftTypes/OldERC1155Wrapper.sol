// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {OldINftWrapper} from "./OldINftWrapper.sol";

/**
 * @title ERC1155Wrapper
 * @dev Provides logic to transfer ERC1155 tokens
 */
contract OldERC1155Wrapper is OldINftWrapper {
    /**
     * @dev Transfer the nft to the `recipient`
     *
     * @param _sender Address of the current owner of the nft
     * @param _recipient Address that will receive the nft
     * @param _nftContract Address of the nft contract
     * @param _nftId Id of the nft
     *
     * @return true if successfully transferred, false otherwise
     */
    function transferNFT(
        address _sender,
        address _recipient,
        address _nftContract,
        uint256 _nftId
    ) external override returns (bool) {
        // Warning:
        // Since we permit ERC1155s in their entirety, the given nftId may represent a fungible token (amount > 1),
        // in which case they are treated as non-fungible by hard coding the amount to 1.
        IERC1155(_nftContract).safeTransferFrom(_sender, _recipient, _nftId, 1, "");
        return true;
    }

    function isOwner(address _owner, address _nftContract, uint256 _tokenId) external view override returns (bool) {
        return IERC1155(_nftContract).balanceOf(_owner, _tokenId) > 0;
    }
}
