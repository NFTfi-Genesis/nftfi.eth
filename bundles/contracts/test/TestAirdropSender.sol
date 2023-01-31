// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "./TestAirdropERC721.sol";

contract TestAirdropSender {
    TestAirdropERC721 public airdrop;

    constructor(address _airdrop) {
        airdrop = TestAirdropERC721(_airdrop);
    }

    function doAirdrop(uint256 tokenId) external {
        airdrop.mint(msg.sender, tokenId);
    }
}
