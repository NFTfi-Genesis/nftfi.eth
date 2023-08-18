// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "./TestAirdrop.sol";

contract TestAirdropSender {
    TestAirdrop public airdrop;

    constructor(address _airdrop) {
        airdrop = TestAirdrop(_airdrop);
    }

    function doAirdrop(uint256 tokenId) external {
        airdrop.mint(msg.sender, tokenId);
    }
}
