// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestAirdropERC1155 is ERC1155 {
    constructor() ERC1155("") {
        // solhint-disable-previous-line no-empty-blocks
    }

    function mint(
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public {
        _mint(to, id, value, data);
    }

    function mintToSender(
        uint256 id,
        uint256 value,
        bytes memory data
    ) public {
        _mint(msg.sender, id, value, data);
    }
}
