// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract TestNonBundleRootOwner is ERC721Holder {
    function rootOwnerOfChild(address, uint256) public pure returns (bytes32 rootOwner) {
        return bytes32("");
    }
}
