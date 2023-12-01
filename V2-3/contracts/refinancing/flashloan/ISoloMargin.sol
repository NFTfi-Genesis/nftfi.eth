// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./IFlashloan.sol";

/**
 * @title ISoloMargin
 * @author NFTfi
 * @dev Interface for dYdX's SoloMargin contract.
 * It includes essential methods needed to interact with the SoloMargin contract.
 * These methods are used for initiating flash loans and getting token address of the market.
 */
interface ISoloMargin {
    /**
     * @dev Function to bundle multiple operations in a single transaction.
     * The operations are executed atomically and the state is maintained to ensure protocol's solvency.
     * @param accounts An array of AccountInfo objects, which contains the address and number of each account involved.
     * @param actions An array of ActionArgs objects, representing the actions to be executed.
     */
    function operate(IFlashloan.AccountInfo[] memory accounts, IFlashloan.ActionArgs[] memory actions) external;

    /**
     * @dev Function to get the token address of the market based on the given marketId.
     * @param marketId The ID of the market to get the token address for.
     * @return Address of the token for the specified market.
     */
    function getMarketTokenAddress(uint256 marketId) external view returns (address);
}
