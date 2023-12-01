// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./DirectLoanBaseMinimal.sol";
import "../../../utils/ContractKeys.sol";

/**
 * @title  DirectLoanProRatedOffer
 * @author NFTfi
 * @notice Main contract for NFTfi Direct Loans ProRated Type. This contract manages the ability to create NFT-backed
 * peer-to-peer loans type ProRated (pro-rata interest loan) where the user only pays the principal plus pro-rata
 * interest if repaid early.
 *
 * There are two ways to commence an NFT-backed loan:
 *
 * a. The borrower accepts a lender's offer by calling `acceptOffer`.
 *   1. the borrower calls nftContract.approveAll(NFTfi), approving the NFTfi contract to move their NFT's on their
 * be1alf.
 *   2. the lender calls erc20Contract.approve(NFTfi), allowing NFTfi to move the lender's ERC20 tokens on their
 * behalf.
 *   3. the lender signs an off-chain message, proposing its offer terms.
 *   4. the borrower calls `acceptOffer` to accept these terms and enter into the loan. The NFT is stored in
 * the contract, the borrower receives the loan principal in the specified ERC20 currency, the lender receives an
 * NFTfi promissory note (in ERC721 form) that represents the rights to either the principal-plus-interest, or the
 * underlying NFT collateral if the borrower does not pay back in time, and the borrower receives obligation receipt
 * (in ERC721 form) that gives them the right to pay back the loan and get the collateral back.
 *
 * The lender can freely transfer and trade this ERC721 promissory note as they wish, with the knowledge that
 * transferring the ERC721 promissory note tranfsers the rights to principal-plus-interest and/or collateral, and that
 * they will no longer have a claim on the loan. The ERC721 promissory note itself represents that claim.
 *
 * The borrower can freely transfer and trade this ERC721 obligaiton receipt as they wish, with the knowledge that
 * transferring the ERC721 obligaiton receipt tranfsers the rights right to pay back the loan and get the collateral
 * back.
 *
 *
 * A loan may end in one of two ways:
 * - First, a borrower may call NFTfi.payBackLoan() and pay back the loan plus interest at any time, in which case they
 * receive their NFT back in the same transaction.
 * - Second, if the loan's duration has passed and the loan has not been paid back yet, a lender can call
 * NFTfi.liquidateOverdueLoan(), in which case they receive the underlying NFT collateral and forfeit the rights to the
 * principal-plus-interest, which the borrower now keeps.
 */
contract DirectLoanProRatedOffer is DirectLoanBaseMinimal {
    /* ************* */
    /* CUSTOM ERRORS */
    /* ************* */

    error InvalidLenderSignature();
    error NegativeInterestRate();

    /* ********** */
    /* DATA TYPES */
    /* ********** */

    bytes32 public constant LOAN_TYPE = bytes32("DIRECT_LOAN_PRO_RATED_OFFER");

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @dev Sets `hub`
     *
     * @param _admin - Initial admin of this contract.
     * @param  _nftfiHub - NFTfiHub address
     * @param  _permittedErc20s - list of permitted ERC20 token contract addresses
     */
    constructor(
        address _admin,
        address _nftfiHub,
        address[] memory _permittedErc20s
    )
        DirectLoanBaseMinimal(
            _admin,
            _nftfiHub,
            ContractKeys.getIdFromStringKey("DIRECT_LOAN_COORDINATOR"),
            _permittedErc20s
        )
    {
        // solhint-disable-previous-line no-empty-blocks
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice This function is called by the borrower when accepting a lender's offer to begin a loan.
     *
     * @param _offer - The offer made by the lender.
     * @param _signature - The components of the lender's signature.
     * @param _borrowerSettings - Some extra parameters that the borrower needs to set when accepting an offer.
     */
    function acceptOffer(
        Offer memory _offer,
        Signature memory _signature,
        BorrowerSettings memory _borrowerSettings
    ) external whenNotPaused nonReentrant {
        address nftWrapper = _getWrapper(_offer.nftCollateralContract);
        _loanSanityChecks(_offer, nftWrapper);
        _loanSanityChecksOffer(_offer);
        _acceptOffer(
            LOAN_TYPE,
            _setupLoanTerms(_offer, nftWrapper),
            _setupLoanExtras(_borrowerSettings.revenueSharePartner, _borrowerSettings.referralFeeInBasisPoints),
            _offer,
            _signature
        );
    }

    /* ******************* */
    /* READ-ONLY FUNCTIONS */
    /* ******************* */

    /**
     * @notice This function can be used to view the current quantity of the ERC20 currency used in the specified loan
     * required by the borrower to repay their loan, measured in the smallest unit of the ERC20 currency. Note that
     * since interest accrues every second, once a borrower calls repayLoan(), the amount will have increased slightly.
     *
     * @param _loanId  A unique identifier for this particular loan, sourced from the Loan Coordinator.
     *
     * @return The amount of the specified ERC20 currency required to pay back this loan, measured in the smallest unit
     * of the specified ERC20 currency.
     */
    function getPayoffAmount(uint32 _loanId) external view override returns (uint256) {
        LoanTerms memory loan = loanIdToLoan[_loanId];
        uint256 loanDurationSoFarInSeconds = block.timestamp - uint256(loan.loanStartTime);
        uint256 interestDue = _computeInterestDue(
            loan.loanPrincipalAmount,
            loan.maximumRepaymentAmount,
            loanDurationSoFarInSeconds,
            uint256(loan.loanDuration),
            uint256(loan.loanInterestRateForDurationInBasisPoints)
        );

        return (loan.loanPrincipalAmount) + interestDue;
    }

    /* ****************** */
    /* INTERNAL FUNCTIONS */
    /* ****************** */

    /**
     * @notice This function is called by the borrower when accepting a lender's offer to begin a loan.
     *
     * @param _loanType - The loan type being created.
     * @param _loanTerms - The main Loan Terms struct. This data is saved upon loan creation on loanIdToLoan.
     * @param _loanExtras - The main Loan Terms struct. This data is saved upon loan creation on loanIdToLoanExtras.
     * @param _offer - The offer made by the lender.
     * @param _signature - The components of the lender's signature.
     */
    function _acceptOffer(
        bytes32 _loanType,
        LoanTerms memory _loanTerms,
        LoanExtras memory _loanExtras,
        Offer memory _offer,
        Signature memory _signature
    ) internal {
        // Check loan nonces. These are different from Ethereum account nonces.
        // Here, these are uint256 numbers that should uniquely identify
        // each signature for each user (i.e. each user should only create one
        // off-chain signature for each nonce, with a nonce being any arbitrary
        // uint256 value that they have not used yet for an off-chain NFTfi
        // signature).
        if (_nonceHasBeenUsedForUser[_signature.signer][_signature.nonce]) {
            revert InvalidNonce();
        }

        _nonceHasBeenUsedForUser[_signature.signer][_signature.nonce] = true;

        if (!NFTfiSigningUtils.isValidLenderSignature(_offer, _signature)) {
            revert InvalidLenderSignature();
        }

        uint32 loanId = _createLoan(_loanType, _loanTerms, _loanExtras, msg.sender, _signature.signer, _offer.referrer);

        // Emit an event with all relevant details from this transaction.
        emit LoanStarted(loanId, msg.sender, _signature.signer, _loanTerms, _loanExtras);
    }

    /**
     * @dev Calculates and updates loanInterestRateForDurationInBasisPoints rate
     * based on loanPrincipalAmount and maximumRepaymentAmount
     */
    function _updateInterestRate(uint32 _loanId) internal {
        LoanTerms storage loan = loanIdToLoan[_loanId];
        loan.loanInterestRateForDurationInBasisPoints = _calculateInterestRate(
            loan.loanPrincipalAmount,
            loan.maximumRepaymentAmount
        );
    }

    /**
     * @dev Calculates the payoff amount and admin fee
     *
     * @param _loan - Struct containing all the loan's parameters
     */
    function _payoffAndFee(LoanTerms memory _loan)
        internal
        view
        override
        returns (uint256 adminFee, uint256 payoffAmount)
    {
        // Calculate amounts to send to lender and admins
        uint256 interestDue = _computeInterestDue(
            _loan.loanPrincipalAmount,
            _loan.maximumRepaymentAmount,
            block.timestamp - uint256(_loan.loanStartTime),
            uint256(_loan.loanDuration),
            uint256(_loan.loanInterestRateForDurationInBasisPoints)
        );
        adminFee = LoanChecksAndCalculations.computeAdminFee(interestDue, uint256(_loan.loanAdminFeeInBasisPoints));
        payoffAmount = ((_loan.loanPrincipalAmount) + interestDue) - adminFee;
    }

    /**
     * @dev Creates a `LoanTerms` struct using data sent as the lender's `_offer` on `acceptOffer`.
     * This is needed in order to avoid stack too deep issues.
     */
    function _setupLoanTerms(Offer memory _offer, address _nftWrapper) internal view returns (LoanTerms memory) {
        return
            LoanTerms({
                loanERC20Denomination: _offer.loanERC20Denomination,
                loanPrincipalAmount: _offer.loanPrincipalAmount,
                maximumRepaymentAmount: _offer.maximumRepaymentAmount,
                nftCollateralContract: _offer.nftCollateralContract,
                nftCollateralWrapper: _nftWrapper,
                nftCollateralId: _offer.nftCollateralId,
                loanStartTime: uint64(block.timestamp),
                loanDuration: _offer.loanDuration,
                loanInterestRateForDurationInBasisPoints: _calculateInterestRate(
                    _offer.loanPrincipalAmount,
                    _offer.maximumRepaymentAmount
                ),
                loanAdminFeeInBasisPoints: _offer.loanAdminFeeInBasisPoints,
                borrower: msg.sender
            });
    }

    /**
     * @notice A convenience function that calculates the amount of interest currently due for a given loan. The
     * interest is capped at _maximumRepaymentAmount minus _loanPrincipalAmount.
     *
     * @param _loanPrincipalAmount - The total quantity of principal first loaned to the borrower, measured in the
     * smallest units of the ERC20 currency used for the loan.
     * @param _maximumRepaymentAmount - The maximum amount of money that the borrower would be required to retrieve
     * their collateral. If interestIsProRated is set to false, then the borrower will always have to pay this amount to
     * retrieve their collateral.
     * @param _loanDurationSoFarInSeconds - The elapsed time (in seconds) that has occurred so far since the loan began
     * until repayment.
     * @param _loanTotalDurationAgreedTo - The original duration that the borrower and lender agreed to, by which they
     * measured the interest that would be due.
     * @param _loanInterestRateForDurationInBasisPoints - The interest rate that the borrower and lender agreed would be
     * due after the totalDuration passed.
     *
     * @return The quantity of interest due, measured in the smallest units of the ERC20 currency used to pay this loan.
     */
    function _computeInterestDue(
        uint256 _loanPrincipalAmount,
        uint256 _maximumRepaymentAmount,
        uint256 _loanDurationSoFarInSeconds,
        uint256 _loanTotalDurationAgreedTo,
        uint256 _loanInterestRateForDurationInBasisPoints
    ) internal pure returns (uint256) {
        uint256 interestDueAfterEntireDurationInBasisPoints = (_loanPrincipalAmount *
            _loanInterestRateForDurationInBasisPoints);
        uint256 interestDueAfterElapsedDuration = (interestDueAfterEntireDurationInBasisPoints *
            _loanDurationSoFarInSeconds) /
            _loanTotalDurationAgreedTo /
            uint256(HUNDRED_PERCENT);
        if (_loanPrincipalAmount + interestDueAfterElapsedDuration > _maximumRepaymentAmount) {
            return (_maximumRepaymentAmount - _loanPrincipalAmount);
        } else {
            return interestDueAfterElapsedDuration;
        }
    }

    /**
     * @dev Calculates loanInterestRateForDurationInBasisPoints rate
     * based on loanPrincipalAmount and maximumRepaymentAmount
     */
    function _calculateInterestRate(uint256 _loanPrincipalAmount, uint256 _maximumRepaymentAmount)
        internal
        pure
        returns (uint16)
    {
        uint256 interest = _maximumRepaymentAmount - _loanPrincipalAmount;
        return uint16((interest * HUNDRED_PERCENT) / _loanPrincipalAmount);
    }

    /**
     * @dev Function that performs some validation checks over loan parameters when accepting an offer
     *
     */
    function _loanSanityChecksOffer(LoanData.Offer memory _offer) internal pure {
        if (_offer.maximumRepaymentAmount < _offer.loanPrincipalAmount) {
            revert NegativeInterestRate();
        }
    }
}
