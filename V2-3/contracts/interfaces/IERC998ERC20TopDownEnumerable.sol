// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

interface IERC998ERC20TopDownEnumerable {
    function totalERC20Contracts(uint256 _tokenId) external view returns (uint256);

    function erc20ContractByIndex(uint256 _tokenId, uint256 _index) external view returns (address);
}
