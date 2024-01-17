// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {IRefinancingAdapter} from "./IRefinancingAdapter.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {
    DirectLoanBaseMinimal,
    IDirectLoanCoordinator,
    IERC20
} from "../../loans/direct/loanTypes/DirectLoanBaseMinimal.sol";

/**
 * @title NftfiRefinancingAdapter
 * @author NFTfi
 * @dev This contract is an implementation of the IRefinancingAdapter for the NFTfi platform.
 * It handles operations related to refinancing NFTfi loans such as transferring the borrower role,
 * paying off loans, and retrieving loan and collateral details.
 */
contract NftfiRefinancingAdapter is IRefinancingAdapter {
    error obligationReceiptDoesntExist();

    /**
     * @dev Gets the address of the borrower for a specific NFTfi loan.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @param _loanIdentifier The unique identifier for the NFTfi loan.
     * @return The address of the borrower.
     */
    function getBorrowerAddress(
        address _loanContract,
        uint256 _loanIdentifier
    ) external view override returns (address) {
        IDirectLoanCoordinator coordinator = _getCoordinator(_loanContract);
        uint64 smartNftId = coordinator.getLoanData(uint32(_loanIdentifier)).smartNftId;
        IERC721 obligationReceiptToken = IERC721(coordinator.obligationReceiptToken());
        return obligationReceiptToken.ownerOf(smartNftId);
    }

    /**
     * @dev Transfers the borrower role to this contract for a specific NFTfi loan.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @param _loanIdentifier The unique identifier for the NFTfi loan.
     * @return A boolean value indicating whether the operation was successful.
     */
    function transferBorrowerRole(address _loanContract, uint256 _loanIdentifier) external override returns (bool) {
        IDirectLoanCoordinator coordinator = _getCoordinator(_loanContract);
        uint64 smartNftId = coordinator.getLoanData(uint32(_loanIdentifier)).smartNftId;
        IERC721 obligationReceiptToken = IERC721(coordinator.obligationReceiptToken());
        address borrower = obligationReceiptToken.ownerOf(smartNftId);
        if (borrower == address(0)) revert obligationReceiptDoesntExist();
        obligationReceiptToken.transferFrom(borrower, address(this), smartNftId);
        return (true);
    }

    /**
     * @dev Pays off an NFTfi loan with a specified amount of a specified token.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @param _loanIdentifier The unique identifier for the NFTfi loan.
     * @param _payBackToken The token used to pay back the NFTfi loan.
     * @param _payBackAmount The amount of tokens used to pay back the NFTfi loan.
     * @return A boolean value indicating whether the operation was successful.
     */
    function payOffRefinancable(
        address _loanContract,
        uint256 _loanIdentifier,
        address _payBackToken,
        uint256 _payBackAmount
    ) external override returns (bool) {
        IERC20(_payBackToken).approve(_loanContract, _payBackAmount);
        DirectLoanBaseMinimal(_loanContract).payBackLoan(uint32(_loanIdentifier));
        return (true);
    }

    /**
     * @dev Gets the collateral information for a specific NFTfi loan.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @param _loanIdentifier The unique identifier for the NFTfi loan.
     * @return nftCollateralContract nftCollateralId
     * The address of the collateral token contract and the ID of the collateral.
     */
    function getCollateral(
        address _loanContract,
        uint256 _loanIdentifier
    ) external view override returns (address nftCollateralContract, uint256 nftCollateralId) {
        // struct LoanTerms {
        //     uint256 loanPrincipalAmount;
        //     uint256 maximumRepaymentAmount;
        //     uint256 nftCollateralId;
        //     address loanERC20Denomination;
        //     uint32 loanDuration;
        //     uint16 loanInterestRateForDurationInBasisPoints;
        //     uint16 loanAdminFeeInBasisPoints;
        //     address nftCollateralWrapper;
        //     uint64 loanStartTime;
        //     address nftCollateralContract;
        //     address borrower;
        // }

        (, , nftCollateralId, , , , , , , nftCollateralContract, ) = DirectLoanBaseMinimal(_loanContract).loanIdToLoan(
            uint32(_loanIdentifier)
        );
    }

    /**
     * @dev Retrieves the loan coordinator from a specific NFTfi loan contract.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @return  The loan coordinator contract.
     */

    /**
     * @dev Gets the collateral information for a specific NFTfi loan.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @param _loanIdentifier The unique identifier for the NFTfi loan.
     * @return loanERC20Denomination maximumRepaymentAmount
     *  The address of the payoff token and the required payoff amount.
     */
    function getPayoffDetails(
        address _loanContract,
        uint256 _loanIdentifier
    ) external view override returns (address loanERC20Denomination, uint256 maximumRepaymentAmount) {
        // struct LoanTerms {
        //     uint256 loanPrincipalAmount;
        //     uint256 maximumRepaymentAmount;
        //     uint256 nftCollateralId;
        //     address loanERC20Denomination;
        //     uint32 loanDuration;
        //     uint16 loanInterestRateForDurationInBasisPoints;
        //     uint16 loanAdminFeeInBasisPoints;
        //     address nftCollateralWrapper;
        //     uint64 loanStartTime;
        //     address nftCollateralContract;
        //     address borrower;
        // }
        (, maximumRepaymentAmount, , loanERC20Denomination, , , , , , , ) = DirectLoanBaseMinimal(_loanContract)
            .loanIdToLoan(uint32(_loanIdentifier));
    }

    /**
     * @dev Retrieves the loan coordinator from a specific NFTfi loan contract.
     * @param _loanContract The address of the contract containing the NFTfi loan.
     * @return The loan coordinator contract.
     */
    function _getCoordinator(address _loanContract) private view returns (IDirectLoanCoordinator) {
        DirectLoanBaseMinimal directLoan = DirectLoanBaseMinimal(_loanContract);
        return IDirectLoanCoordinator(directLoan.hub().getContract(directLoan.LOAN_COORDINATOR()));
    }
}
