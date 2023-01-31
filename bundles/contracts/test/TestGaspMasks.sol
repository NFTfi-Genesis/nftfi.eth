// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract TestGaspMasks is ERC721PresetMinterPauserAutoId {
    constructor() ERC721PresetMinterPauserAutoId("GaspMasks", "WTF", "https://example.com/token/") {
        // solhint-disable-previous-line no-empty-blocks
    }
}
