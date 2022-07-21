// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ERC998TopDown.sol";
import "../interfaces/IERC998ERC1155TopDown.sol";

/**
 * @title ERC9981155Extension
 * @author NFTfi
 * @dev ERC998TopDown extension to support ERC1155 children
 */
abstract contract ERC9981155Extension is ERC998TopDown, IERC998ERC1155TopDown, IERC1155Receiver {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    // tokenId => (child address => (child tokenId => balance))
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) internal balances;

    /**
     * @dev Gives child balance for a specific child contract and child id
     * @param _childContract The ERC1155 contract of the child token
     * @param _childTokenId The tokenId of the child token
     */
    function childBalance(
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId
    ) external view override returns (uint256) {
        return balances[_tokenId][_childContract][_childTokenId];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(ERC998TopDown, IERC165)
        returns (bool)
    {
        return
            _interfaceId == type(IERC998ERC1155TopDown).interfaceId ||
            _interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    /**
     * @notice Transfer a ERC1155 child token from top-down composable to address or other top-down composable
     * @param _tokenId The owning token to transfer from
     * @param _to The address that receives the child token
     * @param _childContract The ERC1155 contract of the child token
     * @param _childTokenId The tokenId of the token that is being transferred
     * @param _amount The amount of the token that is being transferred
     * @param _data Additional data with no specified format
     */
    function safeTransferChild(
        uint256 _tokenId,
        address _to,
        address _childContract,
        uint256 _childTokenId,
        uint256 _amount,
        bytes memory _data
    ) external override nonReentrant {
        _validateReceiver(_to);
        _validate1155ChildTransfer(_tokenId);
        _remove1155Child(_tokenId, _childContract, _childTokenId, _amount);
        if (_to == address(this)) {
            _validateAndReceive1155Child(msg.sender, _childContract, _childTokenId, _amount, _data);
        } else {
            IERC1155(_childContract).safeTransferFrom(address(this), _to, _childTokenId, _amount, _data);
            emit Transfer1155Child(_tokenId, _to, _childContract, _childTokenId, _amount);
        }
    }

    /**
     * @notice Transfer batch of ERC1155 child token from top-down composable to address or other top-down composable
     * @param _tokenId The owning token to transfer from
     * @param _to The address that receives the child token
     * @param _childContract The ERC1155 contract of the child token
     * @param _childTokenIds The list of tokenId of the token that is being transferred
     * @param _amounts The list of amount of the token that is being transferred
     * @param _data Additional data with no specified format
     */
    function safeBatchTransferChild(
        uint256 _tokenId,
        address _to,
        address _childContract,
        uint256[] memory _childTokenIds,
        uint256[] memory _amounts,
        bytes memory _data
    ) external override nonReentrant {
        require(_childTokenIds.length == _amounts.length, "ids and amounts length mismatch");
        _validateReceiver(_to);

        _validate1155ChildTransfer(_tokenId);
        for (uint256 i = 0; i < _childTokenIds.length; ++i) {
            uint256 childTokenId = _childTokenIds[i];
            uint256 amount = _amounts[i];

            _remove1155Child(_tokenId, _childContract, childTokenId, amount);
            if (_to == address(this)) {
                _validateAndReceive1155Child(msg.sender, _childContract, childTokenId, amount, _data);
            }
        }

        if (_to != address(this)) {
            IERC1155(_childContract).safeBatchTransferFrom(address(this), _to, _childTokenIds, _amounts, _data);
            emit Transfer1155BatchChild(_tokenId, _to, _childContract, _childTokenIds, _amounts);
        }
    }

    /**
     * @notice A token receives a child token
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external virtual override returns (bytes4) {
        revert("external calls restricted");
    }

    /**
     * @notice A token receives a batch of child tokens
     * param The address that caused the transfer
     * @param _from The owner of the child token
     * @param _ids The list of token id that is being transferred to the parent
     * @param _values The list of amounts of the tokens that is being transferred
     * @param _data Up to the first 32 bytes contains an integer which is the receiving parent tokenId
     * @return the selector of this method
     */
    function onERC1155BatchReceived(
        address,
        address _from,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory _data
    ) external virtual override nonReentrant returns (bytes4) {
        require(_data.length == 32, "data must contain tokenId to transfer the child token to");
        uint256 _receiverTokenId = _parseTokenId(_data);

        for (uint256 i = 0; i < _ids.length; i++) {
            _receive1155Child(_receiverTokenId, msg.sender, _ids[i], _values[i]);
            emit Received1155Child(_from, _receiverTokenId, msg.sender, _ids[i], _values[i]);
        }
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Validates the data of the child token and receives it
     * @param _from The owner of the child token
     * @param _childContract The ERC1155 contract of the child token
     * @param _id The token id that is being transferred to the parent
     * @param _amount The amount of the token that is being transferred
     * @param _data Up to the first 32 bytes contains an integer which is the receiving parent tokenId
     */
    function _validateAndReceive1155Child(
        address _from,
        address _childContract,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) internal virtual {
        require(_data.length == 32, "data must contain tokenId to transfer the child token to");

        uint256 _receiverTokenId = _parseTokenId(_data);
        _receive1155Child(_receiverTokenId, _childContract, _id, _amount);
        emit Received1155Child(_from, _receiverTokenId, _childContract, _id, _amount);
    }

    /**
     * @dev Updates the state to receive a child
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
    ) internal virtual {
        require(_exists(_tokenId), "bundle tokenId does not exist");
        uint256 childTokensLength = childTokens[_tokenId][_childContract].length();
        if (childTokensLength == 0) {
            childContracts[_tokenId].add(_childContract);
        }
        childTokens[_tokenId][_childContract].add(_childTokenId);
        balances[_tokenId][_childContract][_childTokenId] += _amount;
    }

    /**
     * @notice Validates the transfer of a 1155 child
     * @param _fromTokenId The owning token to transfer from
     */
    function _validate1155ChildTransfer(uint256 _fromTokenId) internal virtual {
        _validateTransferSender(_fromTokenId);
    }

    /**
     * @notice Updates the state to remove a ERC1155 child
     * @param _tokenId The owning token to transfer from
     * @param _childContract The ERC1155 contract of the child token
     * @param _childTokenId The tokenId of the token that is being transferred
     * @param _amount The amount of the token that is being transferred
     */
    function _remove1155Child(
        uint256 _tokenId,
        address _childContract,
        uint256 _childTokenId,
        uint256 _amount
    ) internal virtual {
        require(
            _amount != 0 && balances[_tokenId][_childContract][_childTokenId] >= _amount,
            "insufficient child balance for transfer"
        );
        balances[_tokenId][_childContract][_childTokenId] -= _amount;

        if (balances[_tokenId][_childContract][_childTokenId] == 0) {
            // remove child token
            childTokens[_tokenId][_childContract].remove(_childTokenId);

            // remove contract
            if (childTokens[_tokenId][_childContract].length() == 0) {
                childContracts[_tokenId].remove(_childContract);
            }
        }
    }
}
