// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {DirectLoanFixedOffer, NFTfiSigningUtils} from "./DirectLoanFixedOffer.sol";
import {NFTfiCollectionOfferSigningUtils} from "../../../utils/NFTfiCollectionOfferSigningUtils.sol";

/**
 * @title  DirectLoanFixedCollectionOffer
 * @author NFTfi
 * @notice Main contract for NFTfi Direct Loans Fixed Collection Type.
 * This contract manages the ability to create reoccurring NFT-backed
 * peer-to-peer loans of type Fixed (agreed to be a fixed-repayment loan) where the borrower pays the
 * maximumRepaymentAmount regardless of whether they repay early or not.
 * In collection offer type loans the collateral can be any one item (id) of a given NFT collection (contract).
 *
 * To commence an NFT-backed loan:
 *
 * The borrower accepts a lender's offer by calling `acceptOffer`.
 *   1. the borrower calls nftContract.approveAll(NFTfi), approving the NFTfi contract to move their NFT's on their
 * be1alf.
 *   2. the lender calls erc20Contract.approve(NFTfi), allowing NFTfi to move the lender's ERC20 tokens on their
 * behalf.
 *   3. the lender signs a reusable off-chain message, proposing its collection offer terms.
 *   4. the borrower calls `acceptOffer` to accept these terms and enter into the loan. The NFT is stored in
 * the contract, the borrower receives the loan principal in the specified ERC20 currency, the lender receives an
 * NFTfi promissory note (in ERC721 form) that represents the rights to either the principal-plus-interest, or the
 * underlying NFT collateral if the borrower does not pay back in time, and the borrower receives obligation receipt
 * (in ERC721 form) that gives them the right to pay back the loan and get the collateral back.
 *  5. another borrower can also repeat step 4 until the original lender cancels or their
 * wallet runs out of funds with allowance to the contract
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
contract DirectLoanFixedCollectionOffer is DirectLoanFixedOffer {
    /* ************* */
    /* CUSTOM ERRORS */
    /* ************* */

    error CollateralIdNotInRange();
    error MinIdGreaterThanMaxId();
    error OriginalAcceptOfferDisabled();

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @dev Sets `hub` and permitted erc20-s
     *
     * @param _admin - Initial admin of this contract.
     * @param  _nftfiHub - NFTfiHub address
     * @param  _permittedErc20s - list of permitted ERC20 token contract addresses
     */
    constructor(
        address _admin,
        address _nftfiHub,
        address[] memory _permittedErc20s
    ) DirectLoanFixedOffer(_admin, _nftfiHub, _permittedErc20s) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /* ******************* */
    /* READ-ONLY FUNCTIONS */
    /* ******************* */

    /**
     * @notice This function returns a bytes32 value identifying the loan type for the coordinator
     */
    // all caps, because used to be a constant storage and the interface should be the same
    // solhint-disable-next-line func-name-mixedcase
    function LOAN_TYPE() public pure override returns (bytes32) {
        return bytes32("DIRECT_LOAN_FIXED_COLLECTION");
    }

    /**
     * @notice overriding to make it impossible to create a regular offer on this contract (only collection offers)
     */
    function acceptOffer(
        Offer memory,
        Signature memory,
        BorrowerSettings memory
    ) external override whenNotPaused nonReentrant returns (uint32) {
        revert OriginalAcceptOfferDisabled();
    }

    /**
     * @notice This function is called by the borrower when accepting a lender's collection offer to begin a loan.
     *
     * @param _offer - The offer made by the lender.
     * @param _signature - The components of the lender's signature.
     * stolen or otherwise unwanted items
     * @param _borrowerSettings - Some extra parameters that the borrower needs to set when accepting an offer.
     */
    function acceptCollectionOffer(
        Offer memory _offer,
        Signature memory _signature,
        BorrowerSettings memory _borrowerSettings
    ) external whenNotPaused nonReentrant {
        address nftWrapper = _getWrapper(_offer.nftCollateralContract);
        _loanSanityChecks(_offer, nftWrapper);
        _loanSanityChecksOffer(_offer);
        _acceptOffer(
            _setupLoanTerms(_offer, nftWrapper),
            _setupLoanExtras(_borrowerSettings.revenueSharePartner, _borrowerSettings.referralFeeInBasisPoints),
            _offer,
            _signature
        );
    }

    /**
     * @notice This function is called by the borrower when accepting a lender's
     * collection offer with a given id range to begin a loan
     *
     * @param _offer - The offer made by the lender.
     * @param _idRange - min and max (inclusive) Id ranges for collection offers on collections,
     * like ArtBlocks, where multiple collections are defined on one contract differentiated by id-ranges
     * @param _signature - The components of the lender's signature.
     * stolen or otherwise unwanted items
     * @param _borrowerSettings - Some extra parameters that the borrower needs to set when accepting an offer.
     */
    function acceptCollectionOfferWithIdRange(
        Offer memory _offer,
        CollectionIdRange memory _idRange,
        Signature memory _signature,
        BorrowerSettings memory _borrowerSettings
    ) external whenNotPaused nonReentrant {
        address nftWrapper = _getWrapper(_offer.nftCollateralContract);
        _loanSanityChecks(_offer, nftWrapper);
        _loanSanityChecksOffer(_offer);
        _idRangeSanityCheck(_idRange);
        _acceptOfferWithIdRange(
            _setupLoanTerms(_offer, nftWrapper),
            _setupLoanExtras(_borrowerSettings.revenueSharePartner, _borrowerSettings.referralFeeInBasisPoints),
            _offer,
            _idRange,
            _signature
        );
    }

    /* ****************** */
    /* INTERNAL FUNCTIONS */
    /* ****************** */

    /**
     * @notice This function is called by the borrower when accepting a lender's offer
     * to begin a loan with the public function acceptCollectionOffer.
     *
     * @param _loanTerms - The main Loan Terms struct. This data is saved upon loan creation on loanIdToLoan.
     * @param _loanExtras - The main Loan Terms struct. This data is saved upon loan creation on loanIdToLoanExtras.
     * @param _offer - The offer made by the lender.
     * @param _signature - The components of the lender's signature.
     * stolen or otherwise unwanted items
     */
    function _acceptOffer(
        LoanTerms memory _loanTerms,
        LoanExtras memory _loanExtras,
        Offer memory _offer,
        Signature memory _signature
    ) internal override returns (uint32) {
        // still checking the nonce for possible cancellations
        if (_nonceHasBeenUsedForUser[_signature.signer][_signature.nonce]) {
            revert InvalidNonce();
        }
        // Note that we are not invalidating the nonce as part of acceptOffer (as is the case for loan types in general)
        // since the nonce that the lender signed with remains valid for all loans for the collection offer

        Offer memory offerToCheck = _offer;

        offerToCheck.nftCollateralId = 0;

        if (!NFTfiSigningUtils.isValidLenderSignature(offerToCheck, _signature)) {
            revert InvalidLenderSignature();
        }

        uint32 loanId = _createLoan(
            LOAN_TYPE(),
            _loanTerms,
            _loanExtras,
            msg.sender,
            _signature.signer,
            _offer.referrer
        );

        // Emit an event with all relevant details from this transaction.
        emit LoanStarted(loanId, msg.sender, _signature.signer, _loanTerms, _loanExtras);

        return loanId;
    }

    /**
     * @notice This function is called by the borrower when accepting a lender's
     * collection offer with a given id range to begin a loan
     *
     * @param _loanTerms - The main Loan Terms struct. This data is saved upon loan creation on loanIdToLoan.
     * @param _loanExtras - The main Loan Terms struct. This data is saved upon loan creation on loanIdToLoanExtras.
     * @param _idRange - min and max (inclusive) Id ranges for collection offers on collections,
     * like ArtBlocks, where multiple collections are defined on one contract differentiated by id-ranges
     * @param _offer - The offer made by the lender.
     * @param _signature - The components of the lender's signature.
     * stolen or otherwise unwanted items
     */
    function _acceptOfferWithIdRange(
        LoanTerms memory _loanTerms,
        LoanExtras memory _loanExtras,
        Offer memory _offer,
        CollectionIdRange memory _idRange,
        Signature memory _signature
    ) internal {
        // still checking the nonce for possible cancellations
        if (_nonceHasBeenUsedForUser[_signature.signer][_signature.nonce]) {
            revert InvalidNonce();
        }
        // Note that we are not invalidating the nonce as part of acceptOffer (as is the case for loan types in general)
        // since the nonce that the lender signed with remains valid for all loans for the collection offer

        //check for id range
        if (_loanTerms.nftCollateralId < _idRange.minId || _loanTerms.nftCollateralId > _idRange.maxId) {
            revert CollateralIdNotInRange();
        }
        Offer memory offerToCheck = _offer;

        offerToCheck.nftCollateralId = 0;

        if (!NFTfiCollectionOfferSigningUtils.isValidLenderSignatureWithIdRange(offerToCheck, _idRange, _signature)) {
            revert InvalidLenderSignature();
        }

        uint32 loanId = _createLoan(
            LOAN_TYPE(),
            _loanTerms,
            _loanExtras,
            msg.sender,
            _signature.signer,
            _offer.referrer
        );

        // Emit an event with all relevant details from this transaction.
        emit LoanStarted(loanId, msg.sender, _signature.signer, _loanTerms, _loanExtras);
    }

    function _idRangeSanityCheck(CollectionIdRange memory _idRange) internal pure {
        if (_idRange.minId > _idRange.maxId) {
            revert MinIdGreaterThanMaxId();
        }
    }
}
