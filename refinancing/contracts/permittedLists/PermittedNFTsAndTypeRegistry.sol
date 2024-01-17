// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {IPermittedNFTs} from "../interfaces/IPermittedNFTs.sol";
import {INftfiHub} from "../interfaces/INftfiHub.sol";

import {Ownable} from "../utils/Ownable.sol";
import {ContractKeys} from "../utils/ContractKeys.sol";

/**
 * @title  PermittedNFTsAndTypeRegistry
 * @author NFTfi
 * @dev Registry for NFT contracts supported by NFTfi.
 * Each NFT is associated with an NFT Type.
 */
contract PermittedNFTsAndTypeRegistry is Ownable, IPermittedNFTs {
    INftfiHub public hub;
    mapping(bytes32 => address) private nftTypes;

    /**
     * @notice A mapping from an NFT contract's address to the Token type of that contract. A zero Token Type indicates
     * non-permitted.
     */
    mapping(address => bytes32) private nftPermits;

    /* ****** */
    /* EVENTS */
    /* ****** */

    /**
     * @notice This event is fired whenever the admins register a ntf type.
     *
     * @param nftType - Nft type represented by keccak256('nft type').
     * @param nftWrapper - Address of the wrapper contract.
     */
    event TypeUpdated(bytes32 indexed nftType, address indexed nftWrapper);

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
     * @param _admin - Initial admin of this contract.
     * @param _nftfiHub - Address of the NftfiHub contract
     * @param _definedNftTypes - All the ossible nft types
     * @param _definedNftWrappers - All the possible wrappers for the types
     * @param _permittedNftContracts - The addresses of the NFT contracts.
     * @param _permittedNftTypes - The NFT Types. e.g. "CRYPTO_KITTIES"
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    constructor(
        address _admin,
        address _nftfiHub,
        string[] memory _definedNftTypes,
        address[] memory _definedNftWrappers,
        address[] memory _permittedNftContracts,
        string[] memory _permittedNftTypes
    ) Ownable(_admin) {
        hub = INftfiHub(_nftfiHub);
        _setNftTypes(_definedNftTypes, _definedNftWrappers);
        _setNFTPermits(_permittedNftContracts, _permittedNftTypes);
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
    function setNFTPermit(address _nftContract, string memory _nftType) external override onlyOwner {
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
     * @notice This function can be called by anyone to lookup the address of the NftWrapper associated to the
     * `_nftContract` type.
     * @param _nftContract - The address of the NFT contract.
     */
    function getNFTWrapper(address _nftContract) external view override returns (address) {
        bytes32 nftType = nftPermits[_nftContract];
        return getNftTypeWrapper(nftType);
    }

    /**
     * @notice Set or update the wrapper contract address for the given NFT Type.
     * Set address(0) for a nft type for un-register such type.
     *
     * @param _nftType - The nft type, e.g. "ERC721", or "ERC1155".
     * @param _nftWrapper - The address of the wrapper contract that implements INftWrapper behaviour for dealing with
     * NFTs.
     */
    function setNftType(string memory _nftType, address _nftWrapper) external onlyOwner {
        _setNftType(_nftType, _nftWrapper);
    }

    /**
     * @notice Batch set or update the wrappers contract address for the given batch of NFT Types.
     * Set address(0) for a nft type for un-register such type.
     *
     * @param _nftTypes - The nft types, e.g. "ERC721", or "ERC1155".
     * @param _nftWrappers - The addresses of the wrapper contract that implements INftWrapper behaviour for dealing
     * with NFTs.
     */
    function setNftTypes(string[] memory _nftTypes, address[] memory _nftWrappers) external onlyOwner {
        _setNftTypes(_nftTypes, _nftWrappers);
    }

    /**
     * @notice This function can be called by anyone to get the contract address that implements the given nft type.
     *
     * @param  _nftType - The nft type, e.g. bytes32("ERC721"), or bytes32("ERC1155").
     */
    function getNftTypeWrapper(bytes32 _nftType) public view returns (address) {
        return nftTypes[_nftType];
    }

    /**
     * @notice Set or update the wrapper contract address for the given NFT Type.
     * Set address(0) for a nft type for un-register such type.
     *
     * @param _nftType - The nft type, e.g. "ERC721", or "ERC1155".
     * @param _nftWrapper - The address of the wrapper contract that implements INftWrapper behaviour for dealing with
     * NFTs.
     */
    function _setNftType(string memory _nftType, address _nftWrapper) internal {
        // solhint-disable-next-line custom-errors
        require(bytes(_nftType).length != 0, "nftType is empty");
        bytes32 nftTypeKey = ContractKeys.getIdFromStringKey(_nftType);

        nftTypes[nftTypeKey] = _nftWrapper;

        emit TypeUpdated(nftTypeKey, _nftWrapper);
    }

    /**
     * @notice Batch set or update the wrappers contract address for the given batch of NFT Types.
     * Set address(0) for a nft type for un-register such type.
     *
     * @param _nftTypes - The nft types, e.g. keccak256("ERC721"), or keccak256("ERC1155").
     * @param _nftWrappers - The addresses of the wrapper contract that implements INftWrapper behaviour for dealing
     * with NFTs.
     */
    function _setNftTypes(string[] memory _nftTypes, address[] memory _nftWrappers) internal {
        // solhint-disable-next-line custom-errors
        require(_nftTypes.length == _nftWrappers.length, "setNftTypes function information arity mismatch");

        for (uint256 i; i < _nftWrappers.length; ++i) {
            _setNftType(_nftTypes[i], _nftWrappers[i]);
        }
    }

    /**
     * @notice This function changes the permitted list status of an NFT contract. This includes both adding an NFT
     * contract to the permitted list and removing it.
     * @param _nftContract - The address of the NFT contract.
     * @param _nftType - The NFT Type. e.g. bytes32("CRYPTO_KITTIES")
     * - bytes32("") means "disable this permit"
     * - != bytes32("") means "enable permit with the given NFT Type"
     */
    function _setNFTPermit(address _nftContract, string memory _nftType) internal {
        // solhint-disable-next-line custom-errors
        require(_nftContract != address(0), "nftContract is zero address");
        bytes32 nftTypeKey = ContractKeys.getIdFromStringKey(_nftType);

        if (nftTypeKey != 0) {
            // solhint-disable-next-line custom-errors
            require(getNftTypeWrapper(nftTypeKey) != address(0), "NFT type not registered");
        }

        nftPermits[_nftContract] = nftTypeKey;
        emit NFTPermit(_nftContract, nftTypeKey);
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
        // solhint-disable-next-line custom-errors
        require(_nftContracts.length == _nftTypes.length, "setNFTPermits function information arity mismatch");

        for (uint256 i; i < _nftContracts.length; ++i) {
            _setNFTPermit(_nftContracts[i], _nftTypes[i]);
        }
    }
}
