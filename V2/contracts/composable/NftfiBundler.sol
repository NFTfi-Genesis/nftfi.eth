// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "./ERC9981155Extension.sol";
import "./ERC998ERC20Extension.sol";
import "../utils/ContractKeys.sol";
import "../interfaces/IBundleBuilder.sol";
import "../interfaces/INftfiBundler.sol";
import "../interfaces/INftfiHub.sol";
import "../interfaces/IPermittedNFTs.sol";
import "../interfaces/IPermittedERC20s.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title NftfiBundler
 * @author NFTfi
 * @dev ERC998 Top-Down Composable Non-Fungible Token that supports permitted ERC721, ERC1155 and ERC20 children.
 */
contract NftfiBundler is IBundleBuilder, ERC9981155Extension, ERC998ERC20Extension {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    INftfiHub public immutable hub;

    event NewBundle(uint256 bundleId, address indexed sender, address indexed receiver);

    /**
     * @dev Stores the NftfiHub, name and symbol
     *
     * @param _nftfiHub Address of the NftfiHub contract
     * @param _name name of the token contract
     * @param _symbol symbol of the token contract
     */
    constructor(
        address _nftfiHub,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        hub = INftfiHub(_nftfiHub);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(ERC9981155Extension, ERC998ERC20Extension)
        returns (bool)
    {
        return
            _interfaceId == type(IERC721Receiver).interfaceId ||
            _interfaceId == type(INftfiBundler).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    /**
     * @notice Tells if an asset is permitted or not
     * @param _asset address of the asset
     * @return true if permitted, false otherwise
     */
    function permittedAsset(address _asset) public view returns (bool) {
        IPermittedNFTs permittedNFTs = IPermittedNFTs(hub.getContract(ContractKeys.PERMITTED_NFTS));
        return permittedNFTs.getNFTPermit(_asset) > 0;
    }

    /**
     * @notice Tells if the erc20 is permitted or not
     * @param _erc20Contract address of the erc20
     * @return true if permitted, false otherwise
     */
    function permittedErc20Asset(address _erc20Contract) public view returns (bool) {
        IPermittedERC20s permittedERC20s = IPermittedERC20s(hub.getContract(ContractKeys.PERMITTED_BUNDLE_ERC20S));
        return permittedERC20s.getERC20Permit(_erc20Contract);
    }

    /**
     * @dev used by the loan contract to build a bundle from the BundleElements struct at the beginning of a loan,
     * returns the id of the created bundle
     *
     * @param _bundleElements - the lists of erc721-20-1155 tokens that are to be bundled
     * @param _sender sender of the tokens in the bundle - the borrower
     * @param _receiver receiver of the created bundle, normally the loan contract
     */
    function buildBundle(
        BundleElements memory _bundleElements,
        address _sender,
        address _receiver
    ) external override returns (uint256) {
        uint256 bundleId = _safeMint(_receiver);
        require(
            _bundleElements.erc721s.length > 0 ||
                _bundleElements.erc20s.length > 0 ||
                _bundleElements.erc1155s.length > 0,
            "bundle is empty"
        );
        for (uint256 i = 0; i < _bundleElements.erc721s.length; i++) {
            if (_bundleElements.erc721s[i].safeTransferable) {
                IERC721(_bundleElements.erc721s[i].tokenContract).safeTransferFrom(
                    _sender,
                    address(this),
                    _bundleElements.erc721s[i].id,
                    abi.encodePacked(bundleId)
                );
            } else {
                _getChild(_sender, bundleId, _bundleElements.erc721s[i].tokenContract, _bundleElements.erc721s[i].id);
            }
        }

        for (uint256 i = 0; i < _bundleElements.erc20s.length; i++) {
            _getERC20(_sender, bundleId, _bundleElements.erc20s[i].tokenContract, _bundleElements.erc20s[i].amount);
        }

        for (uint256 i = 0; i < _bundleElements.erc1155s.length; i++) {
            IERC1155(_bundleElements.erc1155s[i].tokenContract).safeBatchTransferFrom(
                _sender,
                address(this),
                _bundleElements.erc1155s[i].ids,
                _bundleElements.erc1155s[i].amounts,
                abi.encodePacked(bundleId)
            );
        }

        emit NewBundle(bundleId, _sender, _receiver);
        return bundleId;
    }

    /**
     * @notice Remove all the children from the bundle
     * @dev This method may run out of gas if the list of children is too big. In that case, children can be removed
     *      individually.
     * @param _tokenId the id of the bundle
     * @param _receiver address of the receiver of the children
     */
    function decomposeBundle(uint256 _tokenId, address _receiver) external override nonReentrant {
        require(ownerOf(_tokenId) == msg.sender, "caller is not owner");
        _validateReceiver(_receiver);

        // In each iteration all contracts children are removed, so eventually all contracts are removed
        while (childContracts[_tokenId].length() > 0) {
            address childContract = childContracts[_tokenId].at(0);

            // In each iteration a child is removed, so eventually all contracts children are removed
            while (childTokens[_tokenId][childContract].length() > 0) {
                uint256 childId = childTokens[_tokenId][childContract].at(0);

                uint256 balance = balances[_tokenId][childContract][childId];

                if (balance > 0) {
                    _remove1155Child(_tokenId, childContract, childId, balance);
                    IERC1155(childContract).safeTransferFrom(address(this), _receiver, childId, balance, "");
                    emit Transfer1155Child(_tokenId, _receiver, childContract, childId, balance);
                } else {
                    _removeChild(_tokenId, childContract, childId);

                    try IERC721(childContract).safeTransferFrom(address(this), _receiver, childId) {
                        // solhint-disable-previous-line no-empty-blocks
                    } catch {
                        _oldNFTsTransfer(_receiver, childContract, childId);
                    }
                    emit TransferChild(_tokenId, _receiver, childContract, childId);
                }
            }
        }

        // In each iteration all contracts children are removed, so eventually all contracts are removed
        while (erc20ChildContracts[_tokenId].length() > 0) {
            address erc20Contract = erc20ChildContracts[_tokenId].at(0);
            uint256 balance = erc20Balances[_tokenId][erc20Contract];

            _removeERC20(_tokenId, erc20Contract, balance);
            IERC20(erc20Contract).safeTransfer(_receiver, balance);
            emit TransferERC20(_tokenId, _receiver, erc20Contract, balance);
        }
    }

    /**
     * @dev Update the state to receive a ERC721 child
     * Overrides the implementation to check if the asset is permitted
     * @param _from The owner of the child token
     * @param _tokenId The token receiving the child
     * @param _childContract The ERC721 contract of the child token
     * @param _childTokenId The token that is being transferred to the parent
     */
    function _receiveChild(
        address _from,
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) internal virtual override {
        require(permittedAsset(_childContract), "erc721 not permitted");
        super._receiveChild(_from, _tokenId, _childContract, _childTokenId);
    }

    /**
     * @dev Updates the state to receive a ERC1155 child
     * Overrides the implementation to check if the asset is permitted
     * @param _tokenId The token receiving the child
     * @param _childContract The ERC1155 contract of the child token
     * @param _childTokenId The token id that is being transferred to the parent
     * @param _amount The amount of the token that is being transferred
     */
    function _receive1155Child(
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId,
        uint256 _amount
    ) internal virtual override {
        require(permittedAsset(_childContract), "erc1155 not permitted");
        super._receive1155Child(_tokenId, _childContract, _childTokenId, _amount);
    }

    /**
     * @notice Store data for the received ERC20
     * @param _from The current owner address of the ERC20 tokens that are being transferred.
     * @param _tokenId The token to transfer the ERC20 tokens to.
     * @param _erc20Contract The ERC20 token contract
     * @param _value The number of ERC20 tokens to transfer
     */
    function _receiveErc20Child(
        address _from,
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _value
    ) internal virtual override {
        require(permittedErc20Asset(_erc20Contract), "erc20 not permitted");
        super._receiveErc20Child(_from, _tokenId, _erc20Contract, _value);
    }
}
