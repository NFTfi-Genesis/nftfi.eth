// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./utils/Ownable.sol";

/**
 * @title TokenUtilityAccounting
 * @author NFTfi
 * @dev
 */
contract TokenUtilityAccounting is Ownable {
    mapping(address => bool) public tokenLocks;

    mapping(address => uint256) public weightedAvgLockTimes;
    mapping(address => uint256) public amounts;

    // these two only needed if we wanted to distribute a finite,
    // given amount of rewards proportionally for locking times and amounts acrued
    uint256 public totalWeightedAvgLockTime;
    uint256 public totalAmount;

    event Update(
        address indexed _user,
        uint256 _weightedAvgLockTime,
        uint256 _acruedUserAmount,
        uint256 _totalWeightedAvgLockTime,
        uint256 _totalAmount
    );

    constructor(address _admin, address[] memory _tokenLockAddresses) Ownable(_admin) {
        _addTokenLocks(_tokenLockAddresses);
    }

    modifier onlyTokenLock() {
        require(tokenLocks[msg.sender], "Only token lock");
        _;
    }

    function lock(address _user, uint256 _amount) external onlyTokenLock {
        _updateUserWeightedAvgLockTime(_user, _amount);
        _updateTotalWeightedAvgLockTime(_amount);
        amounts[_user] += _amount;
        totalAmount += _amount;
        emit Update(_user, weightedAvgLockTimes[_user], amounts[_user], totalWeightedAvgLockTime, totalAmount);
    }

    function unlock(address _user, uint256 _amount) external onlyTokenLock {
        amounts[_user] -= _amount;
        totalAmount -= _amount;
        emit Update(_user, weightedAvgLockTimes[_user], amounts[_user], totalWeightedAvgLockTime, totalAmount);
    }

    /**
     * @dev updates weighted avg lock time for a given user based on the added amount
     * @param _user -
     * @param _amount - amount added
     */
    function _updateUserWeightedAvgLockTime(address _user, uint256 _amount) internal {
        weightedAvgLockTimes[_user] = _calculateWeightedAvgLockTime(
            _amount,
            amounts[_user],
            weightedAvgLockTimes[_user]
        );
    }

    /**
     * @dev updates weighted avg lock time for the whole system based on the added amount
     * @param _amount - amount added
     */
    function _updateTotalWeightedAvgLockTime(uint256 _amount) internal {
        totalWeightedAvgLockTime = _calculateWeightedAvgLockTime(_amount, totalAmount, totalWeightedAvgLockTime);
    }

    /**
     * @dev calculates weightedAvgMultiplier virtual timestamp value with
     * a new data point of token _amount weight and the current time
     * This function is either called by _updateAvgMultiplierStart or has to be called after
     * an explicit stake() or a deleteWithdrawRequest(), or any other possible instances,
     * The function takes the existing average and it's weight (existing balance) then calculates
     * it with the new value and weight with a weighted avg calculation between the 2 datapoints.
     * @param _amount - amount added
     * @param _oldAmount - cumulative amount before
     * @param _oldWeightedAvgLockTime -
     */
    function _calculateWeightedAvgLockTime(
        uint256 _amount,
        uint256 _oldAmount,
        uint256 _oldWeightedAvgLockTime
    ) internal view returns (uint256) {
        if (_oldAmount == 0 || _oldWeightedAvgLockTime == 0) {
            // if we are at initial state with just 1 datapoint
            return block.timestamp;
        } else {
            uint256 totalWeight = _oldAmount + _amount;
            // weighted avg calculation between the old value and the new lock timestamp
            return (_oldAmount * _oldWeightedAvgLockTime + _amount * block.timestamp) / totalWeight;
        }
    }

    function _addTokenLocks(address[] memory _tokenLockAddresses) internal {
        for (uint256 index = 0; index < _tokenLockAddresses.length; ++index) {
            tokenLocks[_tokenLockAddresses[index]] = true;
        }
    }

    function addTokenLocks(address[] memory _tokenLockAddresses) external onlyOwner {
        _addTokenLocks(_tokenLockAddresses);
    }

    function removeTokenLocks(address[] memory _tokenLockAddresses) external onlyOwner {
        for (uint256 index = 0; index < _tokenLockAddresses.length; ++index) {
            tokenLocks[_tokenLockAddresses[index]] = false;
        }
    }
}
