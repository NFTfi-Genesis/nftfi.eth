// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

/**
 * @title IRefinancingAdapter
 * @author NFTfi
 *
 * @dev This is the interface for Refinancing Adapters. It provides several methods for managing and retrieving
 * information about contracts that are eligible for refinancing.
 *
 * Adapters should implement this interface
 */
interface IRefinancingAdapter {
    /**
     * @dev Returns the borrower's address for a specific refinancable
     *
     * @param _refinanceableContract Address of the contract containing the refinanceable
     * @param _refinancableIdentifier Unique identifier for the refinanceable.
     *
     * @return Address of the borrower.
     */
    function getBorrowerAddress(address _refinanceableContract, uint256 _refinancableIdentifier)
        external
        returns (address);

    /**
     * @dev Transfers the role of borrower to refinancing contract for a specific refinanceable.
     *
     * @param _refinanceableContract Address of the contract containing the refinanceable
     * @param _refinancableIdentifier Unique identifier for the loan.
     *
     * @return True if the operation was successful.
     */
    function transferBorrowerRole(address _refinanceableContract, uint256 _refinancableIdentifier)
        external
        returns (bool);

    /**
     * @dev Pays off a refinanceable with a specified amount of a specified token.
     *
     * @param _refinanceableContract Address of the contract containing the refinanceable
     * @param _refinancableIdentifier Unique identifier for the refinanceable.
     * @param _payBackToken Token used to pay back the refinanceable.
     * @param _payBackAmount Amount of tokens used to pay back the refinanceable.
     *
     * @return True if the operation was successful.
     */
    function payOffRefinancable(
        address _refinanceableContract,
        uint256 _refinancableIdentifier,
        address _payBackToken,
        uint256 _payBackAmount
    ) external returns (bool);

    /**
     * @dev Returns the collateral information for a specific refinancable.
     *
     * @param _refinanceableContract Address of the contract containing the refinanceable
     * @param _refinancableIdentifier Unique identifier for the refinanceable.
     *
     * @return The address of the collateral token and the amount of collateral.
     */
    function getCollateral(address _refinanceableContract, uint256 _refinancableIdentifier)
        external
        view
        returns (address, uint256);

    /**
     * @dev Returns the payoff details for a specific refinancable.
     *
     * @param _refinanceableContract Address of the contract containing the refinanceable
     * @param _refinancableIdentifier Unique identifier for the loan.
     *
     * @return The address of the payoff token and the required payoff amount.
     */
    function getPayoffDetails(address _refinanceableContract, uint256 _refinancableIdentifier)
        external
        view
        returns (address, uint256);
}
