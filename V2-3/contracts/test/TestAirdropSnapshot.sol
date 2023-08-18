// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract TestAirdropSnapshot is ERC721 {
    address public snapshotedOwner;

    constructor() ERC721("", "") {
        // solhint-disable-previous-line no-empty-blocks
    }

    function snapshotCurrentOwner(address tokenContract, uint256 tokenId) external {
        snapshotedOwner = IERC721(tokenContract).ownerOf(tokenId);
    }

    // 0x57e4be9a
    function allowedMint(uint256 tokenId) external {
        _safeMint(snapshotedOwner, tokenId);
    }
}
