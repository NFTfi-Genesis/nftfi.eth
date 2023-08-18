// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

/**
 * @title IFlashloan
 * @author NFTfi
 * @dev This is an interface for the Flashloan contract.
 * It includes the definitions for data types and function used in the flashloan operations.
 */
interface IFlashloan {
    /**
     * @dev Enum representing the denomination of an asset.
     * Assets can be denominated in Wei or Par.
     */
    enum AssetDenomination {
        Wei,
        Par
    }

    /**
     * @dev Enum representing the reference of an asset amount.
     * Assets can be referenced by a delta (change in value) or target (final value).
     */
    enum AssetReference {
        Delta,
        Target
    }

    /**
     * @dev Enum representing the type of action to be performed.
     * This can be any one among several options including Deposit, Withdraw, Transfer, etc.
     */
    enum ActionType {
        Deposit,
        Withdraw,
        Transfer,
        Buy,
        Sell,
        Trade,
        Liquidate,
        Vaporize,
        Call
    }

    /**
     * @dev Struct representing an asset amount for an action.
     * It includes information about the sign (positive/negative),
     * denomination (Wei/Par), reference (Delta/Target), and the value.
     */
    struct AssetAmount {
        bool sign;
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    /**
     * @dev Struct representing an action.
     * It includes information about the type of action, the accountId,
     * the amount of the asset, market ids, address of the other party,
     * the other account's id, and any additional data.
     */
    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    /**
     * @dev Struct representing the account information.
     * It includes the owner's address and the account number.
     */
    struct AccountInfo {
        address owner;
        uint256 number;
    }

    /**
     * @dev Function that is called after a flash loan operation.
     * @param sender The address initiating the call.
     * @param accountInfo Account related information.
     * @param data The data passed in the call.
     */
    function callFunction(
        address sender,
        AccountInfo memory accountInfo,
        bytes memory data
    ) external;
}
