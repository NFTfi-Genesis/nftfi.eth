// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "./ERC998TopDown.sol";
import "../interfaces/IERC998ERC20TopDown.sol";
import "../interfaces/IERC998ERC20TopDownEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/**
 * @title ERC998ERC20Extension
 * @author NFTfi
 * @dev ERC998TopDown extension to support ERC20 children
 */
abstract contract ERC998ERC20Extension is ERC998TopDown, IERC998ERC20TopDown, IERC998ERC20TopDownEnumerable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // tokenId => ERC20 child contract
    mapping(uint256 => EnumerableSet.AddressSet) internal erc20ChildContracts;

    // tokenId => (token contract => balance)
    mapping(uint256 => mapping(address => uint256)) internal erc20Balances;

    /**
     * @dev Look up the balance of ERC20 tokens for a specific token and ERC20 contract
     * @param _tokenId The token that owns the ERC20 tokens
     * @param _erc20Contract The ERC20 contract
     * @return The number of ERC20 tokens owned by a token
     */
    function balanceOfERC20(uint256 _tokenId, address _erc20Contract) external view virtual override returns (uint256) {
        return erc20Balances[_tokenId][_erc20Contract];
    }

    /**
     * @notice Get ERC20 contract by tokenId and index
     * @param _tokenId The parent token of ERC20 tokens
     * @param _index The index position of the child contract
     * @return childContract The contract found at the tokenId and index
     */
    function erc20ContractByIndex(uint256 _tokenId, uint256 _index) external view virtual override returns (address) {
        return erc20ChildContracts[_tokenId].at(_index);
    }

    /**
     * @notice Get the total number of ERC20 tokens owned by tokenId
     * @param _tokenId The parent token of ERC20 tokens
     * @return uint256 The total number of ERC20 tokens
     */
    function totalERC20Contracts(uint256 _tokenId) external view virtual override returns (uint256) {
        return erc20ChildContracts[_tokenId].length();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC998TopDown) returns (bool) {
        return
            _interfaceId == type(IERC998ERC20TopDown).interfaceId ||
            _interfaceId == type(IERC998ERC20TopDownEnumerable).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    /**
     * @notice Transfer ERC20 tokens to address
     * @param _tokenId The token to transfer from
     * @param _to The address to send the ERC20 tokens to
     * @param _erc20Contract The ERC20 contract
     * @param _value The number of ERC20 tokens to transfer
     */
    function transferERC20(
        uint256 _tokenId,
        address _to,
        address _erc20Contract,
        uint256 _value
    ) external virtual override {
        _validateERC20Value(_value);
        _validateReceiver(_to);
        _validateERC20Transfer(_tokenId);
        _removeERC20(_tokenId, _erc20Contract, _value);

        IERC20(_erc20Contract).safeTransfer(_to, _value);
        emit TransferERC20(_tokenId, _to, _erc20Contract, _value);
    }

    /**
     * @notice Get ERC20 tokens from ERC20 contract.
     * @dev This contract has to be approved first by _erc20Contract
     */
    function getERC20(
        address,
        uint256,
        address,
        uint256
    ) external pure override {
        revert("external calls restricted");
    }

    /**
     * @notice NOT SUPPORTED
     * Intended to transfer ERC223 tokens. ERC223 tokens can be transferred as regular ERC20
     */
    function transferERC223(
        uint256,
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual override {
        revert("TRANSFER_ERC223_NOT_SUPPORTED");
    }

    /**
     * @notice NOT SUPPORTED
     * Intended to receive ERC223 tokens. ERC223 tokens can be deposited as regular ERC20
     */
    function tokenFallback(
        address,
        uint256,
        bytes calldata
    ) external virtual override {
        revert("TOKEN_FALLBACK_ERC223_NOT_SUPPORTED");
    }

    /**
     * @notice Get ERC20 tokens from ERC20 contract.
     * @dev This contract has to be approved first by _erc20Contract
     * @param _from The current owner address of the ERC20 tokens that are being transferred.
     * @param _tokenId The token to transfer the ERC20 tokens to.
     * @param _erc20Contract The ERC20 token contract
     * @param _value The number of ERC20 tokens to transfer
     */
    function _getERC20(
        address _from,
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _value
    ) internal {
        _validateERC20Value(_value);
        _receiveErc20Child(_from, _tokenId, _erc20Contract, _value);
        IERC20(_erc20Contract).safeTransferFrom(_from, address(this), _value);
    }

    /**
     * @notice Validates the value of a ERC20 transfer
     * @param _value The number of ERC20 tokens to transfer
     */
    function _validateERC20Value(uint256 _value) internal virtual {
        require(_value > 0, "zero amount");
    }

    /**
     * @notice Validates the transfer of a ERC20
     * @param _fromTokenId The owning token to transfer from
     */
    function _validateERC20Transfer(uint256 _fromTokenId) internal virtual {
        _validateTransferSender(_fromTokenId);
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
    ) internal virtual {
        require(_exists(_tokenId), "bundle tokenId does not exist");
        uint256 erc20Balance = erc20Balances[_tokenId][_erc20Contract];
        if (erc20Balance == 0) {
            erc20ChildContracts[_tokenId].add(_erc20Contract);
        }
        erc20Balances[_tokenId][_erc20Contract] += _value;
        emit ReceivedERC20(_from, _tokenId, _erc20Contract, _value);
    }

    /**
     * @notice Updates the state to remove ERC20 tokens
     * @param _tokenId The token to transfer from
     * @param _erc20Contract The ERC20 contract
     * @param _value The number of ERC20 tokens to transfer
     */
    function _removeERC20(
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _value
    ) internal virtual {
        uint256 erc20Balance = erc20Balances[_tokenId][_erc20Contract];
        require(erc20Balance >= _value, "not enough token available to transfer");
        uint256 newERC20Balance = erc20Balance - _value;
        erc20Balances[_tokenId][_erc20Contract] = newERC20Balance;
        if (newERC20Balance == 0) {
            erc20ChildContracts[_tokenId].remove(_erc20Contract);
        }
    }
}
