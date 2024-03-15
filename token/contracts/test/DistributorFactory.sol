// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../utils/Ownable.sol";
import "../MerkleDistributor.sol";
import "../DistributorRegistry.sol";

contract DistributorFactory is Ownable {
    DistributorRegistry public immutable distributorRegistry;
    address public immutable nftfi;
    address public immutable tokenLock;

    constructor(
        address _admin,
        address _distributorRegistry,
        address _nftfi,
        address _tokenLock
    ) Ownable(_admin) {
        distributorRegistry = DistributorRegistry(_distributorRegistry);
        nftfi = _nftfi;
        tokenLock = _tokenLock;
    }

    function addDistributor(
        bytes32 _merkleRoot,
        uint256 _claimCutoffDate,
        uint256 _seasonNumber
    ) public onlyOwner {
        MerkleDistributor merkleDistributor = new MerkleDistributor(
            _merkleRoot,
            owner(),
            nftfi,
            tokenLock,
            address(distributorRegistry),
            _claimCutoffDate
        );
        distributorRegistry.addDistributor(_seasonNumber, address(merkleDistributor));
    }

    function replaceDistributor(
        bytes32 _merkleRoot,
        uint256 _claimCutoffDate,
        uint256 _seasonNumber
    ) public onlyOwner {
        distributorRegistry.removeDistributor(_seasonNumber);
        addDistributor(_merkleRoot, _claimCutoffDate, _seasonNumber);
    }

    function acceptDistributorRegistryTransferOwnership() public {
        distributorRegistry.acceptTransferOwnership();
    }
}
