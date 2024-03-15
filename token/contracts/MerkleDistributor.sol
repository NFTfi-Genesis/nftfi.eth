// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import "./NFTFI.sol";
import "./DistributorTokenLock.sol";

import "./utils/Ownable.sol";

/**
 * @title MerkleDistributor
 * @author NFTfi
 * @dev Modified version of Uniswap's MerkleDistributor
 * https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol
 * Main difference: in claim instead of transferring the tokens to the user,
 * we transfer it to the tokenLock contract
 */
contract MerkleDistributor is Ownable, Pausable {
    NFTFI public immutable nftfi;
    DistributorTokenLock public immutable distributorTokenLock;
    address public immutable distributorRegistry;
    uint256 public immutable claimCutoffDate;

    bytes32 public merkleRoot;

    mapping(uint256 => uint256) private claimedBitMap;

    event Claimed(uint256 _index, uint256 _amount, bytes32[] _merkleProof, address indexed _account);

    /**
     * @dev Constructor initializes references for NFTfi token and TokenLock contract.
     * It also sets the owner of the contract.
     * @param _admin The initial owner of the contract, usually able to set Merkle roots.
     * @param _nftfi Address of the NFTfi token contract.
     * @param _distributorTokenLock Address of the TokenLock contract where tokens are transferred upon claims.
     */
    constructor(
        bytes32 _merkleRoot,
        address _admin,
        address _nftfi,
        address _distributorTokenLock,
        address _distributorRegistry,
        uint256 _claimCutoffDate
    ) Ownable(_admin) {
        merkleRoot = _merkleRoot;
        nftfi = NFTFI(_nftfi);
        distributorTokenLock = DistributorTokenLock(_distributorTokenLock);
        distributorRegistry = _distributorRegistry;
        claimCutoffDate = _claimCutoffDate;
    }

    function isClaimed(uint256 _index) public view returns (bool) {
        uint256 claimedWordIndex = _index / 256;
        uint256 claimedBitIndex = _index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 _index) private {
        uint256 claimedWordIndex = _index / 256;
        uint256 claimedBitIndex = _index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(
        uint256 _index,
        uint256 _amount,
        bytes32[] memory _merkleProof
    ) external {
        _claim(_index, _amount, _merkleProof, msg.sender);
    }

    function claimFromRegistry(
        uint256 _index,
        uint256 _amount,
        bytes32[] memory _merkleProof,
        address _claimer
    ) external {
        require(msg.sender == distributorRegistry, "Only registry");
        _claim(_index, _amount, _merkleProof, _claimer);
    }

    function _claim(
        uint256 _index,
        uint256 _amount,
        bytes32[] memory _merkleProof,
        address _claimer
    ) internal whenNotPaused {
        require(block.timestamp < claimCutoffDate, "cutoff date elapsed");

        require(!isClaimed(_index), "distributor: already claimed");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(_index, _claimer, _amount));
        require(MerkleProof.verify(_merkleProof, merkleRoot, node), "distributor: invalid proof");

        // Mark it claimed and send the token.
        _setClaimed(_index);

        nftfi.approve(address(distributorTokenLock), _amount);
        distributorTokenLock.lockTokens(_amount, _claimer);

        emit Claimed(_index, _amount, _merkleProof, _claimer);
    }

    /**
     * @dev Drain to admin address in an emergency
     * @param _amount of tokens to drain
     */
    function drain(uint256 _amount) public onlyOwner {
        nftfi.transfer(owner(), _amount);
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - Only the owner can call this method.
     * - The contract must not be paused.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - Only the owner can call this method.
     * - The contract must be paused.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
