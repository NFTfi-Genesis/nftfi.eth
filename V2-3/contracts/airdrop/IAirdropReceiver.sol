// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

/**
 * @title IAirdropReceiver
 * @author NFTfi
 * @dev
 */
interface IAirdropReceiver {
    function pullAirdrop(address _target, bytes calldata _data) external;
}
