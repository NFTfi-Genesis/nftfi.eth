// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

string constant NAME = "NFTfi";
string constant SYMBOL = "NFTFI";

/**
 * @title NFTfiToken
 * @author NFTfi
 * @dev standard ERC20 token
 */
contract NFTfiToken is ERC20Permit {
    constructor(uint256 _initialSupply, address _owner) ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        _mint(_owner, _initialSupply);
    }
}
