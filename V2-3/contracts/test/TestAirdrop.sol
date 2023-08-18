// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestAirdrop is ERC721 {
    constructor() ERC721("", "") {
        // solhint-disable-previous-line no-empty-blocks
    }

    // 0x57e4be9a
    function allowedMint(uint256 tokenId) external {
        _safeMint(msg.sender, tokenId);
    }

    // 0x80d2f826
    function notAllowedMint(uint256 tokenId) external {
        _safeMint(msg.sender, tokenId);
    }

    function mint(address _to, uint256 _tokenId) public {
        _safeMint(_to, _tokenId);
    }
}
