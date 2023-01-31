// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./TestLegacyERC721.sol";

contract TestnetAirdrops {
    address public targetCollection;
    uint256 public targetId;

    TestnetAirdropERC721 public erc721;
    TestnetAirdropERC1155 public erc1155;
    TestnetAirdropERC20 public erc20;
    TestnetAirdropLegacyERC721 public legacyErc721;

    constructor() {
        erc721 = new TestnetAirdropERC721();
        erc1155 = new TestnetAirdropERC1155();
        erc20 = new TestnetAirdropERC20();
        legacyErc721 = new TestnetAirdropLegacyERC721();
    }

    function updateTargetAsset(address collection, uint256 id) public {
        targetCollection = collection;
        targetId = id;
    }

    function checkTargetAssetOwnership(address caller) internal view {
        require(IERC721(targetCollection).ownerOf(targetId) == caller, "does not own target asset");
    }

    function getErc721() public {
        erc721.mint(msg.sender);
    }

    function getErc721(address _to) public {
        erc721.mint(_to);
    }

    function getErc721Check() public {
        checkTargetAssetOwnership(msg.sender);
        erc721.mint(msg.sender);
    }

    function getErc1155() public {
        erc1155.mint(msg.sender, 5);
    }

    function getErc20() public {
        erc20.mint(msg.sender, 1 ether);
    }

    function getLegacyErc721() public {
        legacyErc721.mint(msg.sender);
    }
}

contract TestnetAirdropERC721 is ERC721, Ownable {
    uint256 public idCounter;

    constructor() ERC721("", "") {
        // solhint-disable-previous-line no-empty-blocks
    }

    function mint(address _to) public onlyOwner {
        _safeMint(_to, idCounter);
        ++idCounter;
    }
}

contract TestnetAirdropERC1155 is ERC1155, Ownable {
    uint256 public idCounter;

    constructor() ERC1155("") {
        // solhint-disable-previous-line no-empty-blocks
    }

    function mint(address to, uint256 value) public onlyOwner {
        _mint(to, idCounter, value, "");
        ++idCounter;
    }
}

contract TestnetAirdropERC20 is ERC20, Ownable {
    constructor() ERC20("", "") {
        // solhint-disable-previous-line no-empty-blocks
    }

    function mint(address to, uint256 value) public onlyOwner {
        _mint(to, value);
    }
}

contract TestnetAirdropLegacyERC721 is LegacyERC721BasicToken, Ownable {
    uint256 public idCounter;

    function mint(address _to) public onlyOwner {
        _mint(_to, idCounter);
        idCounter++;
    }
}
