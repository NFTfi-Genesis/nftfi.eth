// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./BaseTokenLock.sol";

/**
 * @title TokenLock
 * @author NFTfi
 * @dev This contract allows users to lock tokens with a request-based withdrawal mechanism. Withdrawals
 * have cooldown periods and need a protocol signature if the tokens withdrawn come from the distributor
 * and not from an external source. It integrates with a `TokenUtilityAccounting` contract.
 */
contract ExternalTokenLock is BaseTokenLock {
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
    ) BaseTokenLock(_admin, _nftfi, _tokenUtilityAccounting, _cooldown) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Allows a user to lock their externally owned tokens.
     * User gets an amount of "utility points" in return for the amount
     * of time their tokens are locked and not requested yet.
     * User has to call requestWithdrawal to start cooldown before being able to withdraw tokens.
     * @param _amount Amount of tokens to lock.
     */
    function lockTokens(uint256 _amount) external {
        _lockTokens(_amount, msg.sender);
    }

    /**
     * @dev Allows a user to request a withdrawal of their tokens.
     * @param _amount Amount of tokens to request for withdrawal.
     */
    function requestWithdrawal(uint256 _amount) external {
        _requestWithdrawal(_amount, msg.sender);
        tokenUtilityAccounting.unlock(msg.sender, _amount);
    }

    /**
     * @dev Allows a user to delete their withdrawal request. Re-locks in TokenUtilityAccounting,
     * so user will receive "utility points" again.
     * @param _amount Amount of tokens that were requested for withdrawal.
     * @param _requestTimestamp Timestamp of the original withdrawal request.
     */
    function deleteWithdrawRequest(uint256 _amount, uint256 _requestTimestamp) external {
        _checkAndDeleteRequest(_amount, msg.sender, _requestTimestamp);
        tokenUtilityAccounting.lock(msg.sender, _amount);
    }

    /**
     * @dev Allows a user to withdraw their tokens after a cooldown,
     * with a protocol signature if we withdraw from the ditributor locked pot.
     * @param _amount Amount of tokens to withdraw.
     * @param _requestTimestamp Timestamp of the original withdrawal request.
     */
    function withdraw(uint256 _amount, uint256 _requestTimestamp) public {
        _withdraw(_amount, _requestTimestamp);
    }

    function withdrawMultiple(uint256[] calldata _amounts, uint256[] calldata _requestTimestamps) external {
        require(_amounts.length == _requestTimestamps.length, "parameter arity mismatch");
        for (uint256 i = 0; i < _amounts.length; ++i) {
            withdraw(_amounts[i], _requestTimestamps[i]);
        }
    }
}
