// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../IPermittedNFTs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  PermittedNFTs
 * @author NFTfi
 * @dev Registry for NFT contracts supported by NFTfi.
 * Each NFT is associated with an NFT Type.
 */
contract PermittedNFTs is Ownable, IPermittedNFTs {
    /**
     * @notice A mapping from an NFT contract's address to the Token type of that contract. A zero Token Type indicates
     * non-permitted.
     */
    mapping(address => bytes32) private nftPermits;

    /* ****** */
    /* EVENTS */
    /* ****** */

    /**
     * @notice This event is fired whenever the admin sets a NFT's permit.
     *
     * @param nftContract - Address of the NFT contract.
     * @param nftType - NTF type e.g. bytes32("CRYPTO_KITTIES")
     */
    event NFTPermit(address indexed nftContract, bytes32 indexed nftType);

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @dev Sets `nftTypeRegistry`
     * Initialize `nftPermits` with a batch of permitted NFTs
     *
     * @param _nftContracts - The addresses of the NFT contracts.
     * @param _nftTypes - The NFT Types. e.g. "CRYPTO_KITTIES"
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    constructor(address[] memory _nftContracts, string[] memory _nftTypes) {
        _setNFTPermits(_nftContracts, _nftTypes);
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice This function can be called by admins to change the permitted list status of an NFT contract. This
     * includes both adding an NFT contract to the permitted list and removing it.
     * `_nftContract` can not be zero address.
     *
     * @param _nftContract - The address of the NFT contract.
     * @param _nftType - The NFT Type. e.g. "CRYPTO_KITTIES"
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    function setNFTPermit(address _nftContract, string memory _nftType) external onlyOwner {
        _setNFTPermit(_nftContract, _nftType);
    }

    /**
     * @notice This function can be called by admins to change the permitted list status of a batch NFT contracts. This
     * includes both adding an NFT contract to the permitted list and removing it.
     * `_nftContract` can not be zero address.
     *
     * @param _nftContracts - The addresses of the NFT contracts.
     * @param _nftTypes - The NFT Types. e.g. "CRYPTO_KITTIES"
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    function setNFTPermits(address[] memory _nftContracts, string[] memory _nftTypes) external onlyOwner {
        _setNFTPermits(_nftContracts, _nftTypes);
    }

    /**
     * @notice This function can be called by anyone to lookup the Nft Type associated with the contract.
     * @param  _nftContract - The address of the NFT contract.
     * @notice Returns the NFT Type:
     * - bytes32("") means "not permitted"
     * - != bytes32("") means "permitted with the given NFT Type"
     */
    function getNFTPermit(address _nftContract) external view override returns (bytes32) {
        return nftPermits[_nftContract];
    }

    /**
     * @notice This function changes the permitted list status of an NFT contract. This includes both adding an NFT
     * contract to the permitted list and removing it.
     * @param _nftContract - The address of the NFT contract.
     * @param _nftType - The NFT Type. e.g. bytes32("CRYPTO_KITTIES")
     * - bytes32("") means "disable this permit"
     * - != bytes32("") means "enable permit with the given NFT Type"
     */
    // solhint-disable-next-line no-unused-vars
    function _setNFTPermit(address _nftContract, string memory _nftType) internal {
        require(_nftContract != address(0), "nftContract is zero address");

        nftPermits[_nftContract] = bytes32("permit");
        emit NFTPermit(_nftContract, bytes32("permit"));
    }

    /**
     * @notice This function changes the permitted list status of a batch NFT contracts. This includes both adding an
     * NFT contract to the permitted list and removing it.
     * @param _nftContracts - The addresses of the NFT contracts.
     * @param _nftTypes - The NFT Types. e.g. "CRYPTO_KITTIES"
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    function _setNFTPermits(address[] memory _nftContracts, string[] memory _nftTypes) internal {
        require(_nftContracts.length == _nftTypes.length, "setNFTPermits function information arity mismatch");

        for (uint256 i = 0; i < _nftContracts.length; ++i) {
            _setNFTPermit(_nftContracts[i], _nftTypes[i]);
        }
    }
}
