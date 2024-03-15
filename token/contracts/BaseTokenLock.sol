// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import "./NFTFI.sol";
import "./TokenUtilityAccounting.sol";

import "./utils/Ownable.sol";

/**
 * @title TokenLock
 * @author NFTfi
 * @dev This contract allows users to lock tokens with a request-based withdrawal mechanism. Withdrawals
 * have cooldown periods and need a protocol signature if the tokens withdrawn come from the distributor
 * and not from an external source. It integrates with a `TokenUtilityAccounting` contract.
 */
abstract contract BaseTokenLock is Ownable, Pausable {
    using SafeERC20 for NFTFI;

    // Contract that calculates a token utility score with a (locked) time based multiplier.
    // Optional, can be left zero-address and added in the future.
    TokenUtilityAccounting public tokenUtilityAccounting;
    NFTFI public immutable nftfiToken;

    // Cooldown time before a withdrawal can be executed after request in seconds
    uint256 public cooldown;

    mapping(address => uint256) public lockedTokens;
    mapping(address => uint256) public distributorLockedTokens;

    mapping(address => uint256) public withdrawalRequestAmounts;

    mapping(bytes32 => bool) public withdrawRequests;

    /**
     * @dev Emitted when tokens are locked in the contract.
     * @param _amount The amount of tokens locked.
     * @param _user Address of the user who locked the tokens.
     */
    event Locked(uint256 _amount, address indexed _user);

    /**
     * @dev Emitted when a user requests to withdraw their tokens.
     * @param _amount The amount of tokens the user wants to withdraw.
     * @param _user Address of the user requesting the withdrawal.
     */
    event WithdrawalRequested(uint256 _amount, address indexed _user, uint256 _timestamp);

    /**
     * @dev Emitted when a user withdraws their tokens.
     * @param _amount The amount of tokens withdrawn.
     * @param _user Address of the user making the withdrawal.
     */
    event Withdrawn(uint256 _amount, address indexed _user);

    /**
     * @dev Emitted when a user's withdrawal request is deleted.
     * @param _amount The amount of tokens the user initially wanted to withdraw.
     * @param _user Address of the user whose request was deleted.
     * @param _timestamp When request was made (unix timstamp in seconds)
     */
    event WithdrawalRequestDeleted(uint256 _amount, address indexed _user, uint256 _timestamp);

    /**
     * @dev Initializes the contract, setting initial admin, token, distributor, and cooldown values.
     * @param _admin Admin's address.
     * @param _nftfi Address of the NFTFI token.
     * @param _cooldown Cooldown time in seconds.
     */
    constructor(
        address _admin,
        address _nftfi,
        address _tokenUtilityAccounting,
        uint256 _cooldown
    ) Ownable(_admin) {
        nftfiToken = NFTFI(_nftfi);
        tokenUtilityAccounting = TokenUtilityAccounting(_tokenUtilityAccounting);
        cooldown = _cooldown;
    }

    /**
     * @dev Internal function to handle locking of tokens.
     * @param _amount Amount of tokens to lock.
     * @param _beneficiary Address for whom the tokens are being locked.
     */
    function _lockTokens(uint256 _amount, address _beneficiary) internal whenNotPaused {
        lockedTokens[_beneficiary] += _amount;
        tokenUtilityAccounting.lock(_beneficiary, _amount);
        nftfiToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Locked(_amount, _beneficiary);
    }

    /**
     * @dev Internal request, makes it possible that we request a withdrawal right away
     * after tokens are claimed without locking and unlocking.
     * @param _amount Amount of tokens to request for withdrawal.
     */
    function _requestWithdrawal(uint256 _amount, address _beneficiary) internal whenNotPaused {
        require(
            _amount + withdrawalRequestAmounts[_beneficiary] <= lockedTokens[_beneficiary],
            "request amounts > total"
        );
        bytes32 requestHash = _calculateRequestHash(_amount, _beneficiary, block.timestamp);
        require(!withdrawRequests[requestHash], "duplicate request");
        withdrawalRequestAmounts[_beneficiary] += _amount;
        withdrawRequests[requestHash] = true;
        emit WithdrawalRequested(_amount, _beneficiary, block.timestamp);
    }

    function _checkAndDeleteRequest(
        uint256 _amount,
        address _beneficiary,
        uint256 _requestTimestamp
    ) internal whenNotPaused {
        bytes32 requestHash = _calculateRequestHash(_amount, _beneficiary, _requestTimestamp);
        require(withdrawRequests[requestHash], "no request");
        require(_amount <= withdrawalRequestAmounts[msg.sender], "amount > requestAmounts");
        delete withdrawRequests[requestHash];
        withdrawalRequestAmounts[msg.sender] -= _amount;
        emit WithdrawalRequestDeleted(_amount, msg.sender, _requestTimestamp);
    }

    /**
     * @dev Allows a user to withdraw their tokens after a cooldown,
     * with a protocol signature if we withdraw from the ditributor locked pot.
     * @param _amount Amount of tokens to withdraw.
     * @param _requestTimestamp Timestamp of the original withdrawal request.
     */
    function _withdraw(uint256 _amount, uint256 _requestTimestamp) internal whenNotPaused {
        require(_amount <= lockedTokens[msg.sender], "withdraw amount > total");
        // cooldown checking feature can be turned off by setting it to 0
        if (cooldown > 0) {
            require(block.timestamp >= _requestTimestamp + cooldown, "cooldown not up");
            _checkAndDeleteRequest(_amount, msg.sender, _requestTimestamp);
        }
        if (cooldown == 0) {
            if (withdrawalRequestAmounts[msg.sender] > 0) {
                // if cooldown is disabled, we have to delete existing
                // cooldowns, otherwise re-using it will cause anomalies
                _checkAndDeleteRequest(_amount, msg.sender, _requestTimestamp);
            } else {
                // if there are no withdrawalRequests anymore, we have to unlock here
                tokenUtilityAccounting.unlock(msg.sender, _amount);
            }
        }

        lockedTokens[msg.sender] -= _amount;

        nftfiToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(_amount, msg.sender);
    }

    /**
     * @dev Allows the owner to set a new TokenUtilityAccounting contract.
     * @param _newTokenUtilityAccounting Address of the new TokenUtilityAccounting contract.
     */
    function setTokenUtilityAccounting(address _newTokenUtilityAccounting) external onlyOwner {
        tokenUtilityAccounting = TokenUtilityAccounting(_newTokenUtilityAccounting);
    }

    /**
     * @dev Sets up new cooldown period
     * cooldown checking feature can be turned off by setting it to 0
     * @param _cooldown - Cooldown time before a withdrawal can be executed after request in seconds
     */
    function setCooldown(uint256 _cooldown) external onlyOwner {
        cooldown = _cooldown;
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

    /**
     * @dev Calculates the hash of a withdrawal request.
     * @param _amount Amount of tokens to withdraw.
     * @param _user Address of the user.
     * @param _timestamp Timestamp of the request.
     * @return Hash of the withdrawal request.
     */
    function _calculateRequestHash(
        uint256 _amount,
        address _user,
        uint256 _timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_amount, _user, _timestamp));
    }
}
