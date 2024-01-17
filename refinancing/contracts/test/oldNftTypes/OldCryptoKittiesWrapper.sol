// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {OldINftWrapper} from "./OldINftWrapper.sol";
import {ICryptoKitties} from "../../interfaces/ICryptoKitties.sol";

/**
 * @title CryptoKittiesWrapper
 * @author NFTfi
 * @dev Provides logic to transfer CryptoKitties
 */
contract OldCryptoKittiesWrapper is OldINftWrapper {
    /**
     * @dev Transfers Kitty `_nftId` handled by the contract `_nftContract` from `_sender` to `_recipient`
     *
     * @param _sender - The current owner of the Kitty
     * @param _recipient - The new owner of the Kitty
     * @param _nftContract - CryptoKitties contract
     * @param _nftId - Kitty id
     *
     * @return true if successfully transferred, false otherwise
     */
    function transferNFT(
        address _sender,
        address _recipient,
        address _nftContract,
        uint256 _nftId
    ) external override returns (bool) {
        if (_sender == address(this)) {
            ICryptoKitties(_nftContract).transfer(_recipient, _nftId);
        } else {
            ICryptoKitties(_nftContract).transferFrom(_sender, _recipient, _nftId);
        }

        return true;
    }

    function isOwner(address _owner, address _nftContract, uint256 _tokenId) external view override returns (bool) {
        return ICryptoKitties(_nftContract).ownerOf(_tokenId) == _owner;
    }
}
