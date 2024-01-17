// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

contract FakeNftWrapper {
    function transferNFT(address, address, address, uint256) public {
        selfdestruct(payable(msg.sender));
    }
}
