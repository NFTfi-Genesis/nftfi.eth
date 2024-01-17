// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

/**
 * @title INftTypeRegistry
 * @author NFTfi
 * @dev Interface for NFT Types Registry supported by NFTfi.
 */
interface INftTypeRegistry {
    function setNftType(bytes32 _nftType, address _nftWrapper) external;

    function getNftTypeWrapper(bytes32 _nftType) external view returns (address);
}
