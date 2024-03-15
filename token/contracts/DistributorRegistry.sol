// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./utils/Ownable.sol";
import "./MerkleDistributor.sol";

contract DistributorRegistry is Ownable {
    mapping(uint256 => address) public distributorsBySeason;
    mapping(address => bool) public distributors;

    /**
     * @dev Struct to represent claim data for batch processing.
     * @param rootNumber The Merkle root number associated with the claim.
     * @param index The index within the Merkle tree for this particular claim.
     * @param amount The amount of tokens to be claimed.
     * @param merkleProof The Merkle proof associated with the claim to validate it against the root.
     */
    struct MultiClaimData {
        uint256 seasonNumber;
        uint256 index;
        uint256 amount;
        bytes32[] merkleProof;
    }

    event DistributorAdded(uint256 indexed _seasonNumber, address _distributor);
    event DistributorRemoved(uint256 indexed _seasonNumber, address _distributor);

    constructor(address _admin) Ownable(_admin) {
        // solhint-disable-previous-line no-empty-blocks
    }

    function addDistributor(uint256 _seasonNumber, address _distributor) external onlyOwner {
        require(distributorsBySeason[_seasonNumber] == address(0), "Season number already set");
        distributorsBySeason[_seasonNumber] = _distributor;
        distributors[_distributor] = true;
        emit DistributorAdded(_seasonNumber, _distributor);
    }

    function removeDistributor(uint256 _seasonNumber) external onlyOwner {
        address distributor = distributorsBySeason[_seasonNumber];
        delete distributorsBySeason[_seasonNumber];
        delete distributors[distributor];
        emit DistributorRemoved(_seasonNumber, distributor);
    }

    function isDistributor(address _distributor) external view returns (bool) {
        return distributors[_distributor];
    }

    /**
     * @dev Supports batch claiming, instead of transferring to the recipient directly,
     * tokens are locked in the TokenLock contract.
     * multi claim where amounts are the same will fail with 'duplicate request' (request collision in token lock),
     * users need to claim one by one on the distributors in this case
     * @param _claimData An array containing details for each claim the caller wishes to make.
     */
    function multiClaim(MultiClaimData[] memory _claimData) external {
        for (uint256 i = 0; i < _claimData.length; ++i) {
            uint256 seasonNumber = _claimData[i].seasonNumber;
            uint256 index = _claimData[i].index;
            uint256 amount = _claimData[i].amount;
            bytes32[] memory merkleProof = _claimData[i].merkleProof;

            MerkleDistributor(distributorsBySeason[seasonNumber]).claimFromRegistry(
                index,
                amount,
                merkleProof,
                msg.sender
            );
        }
    }
}
