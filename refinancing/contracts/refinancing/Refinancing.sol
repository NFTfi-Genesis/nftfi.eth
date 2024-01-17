// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {INftfiHub} from "../interfaces/INftfiHub.sol";
import {LoanData} from "../loans/direct/loanTypes/LoanData.sol";
import {RefinancingAdapterRegistry} from "./refinancingAdapters/RefinancingAdapterRegistry.sol";
import {IRefinancingAdapter} from "./refinancingAdapters/IRefinancingAdapter.sol";
import {DirectLoanFixedOffer, ContractKeys} from "../loans/direct/loanTypes/DirectLoanFixedOffer.sol";
import {DirectLoanFixedCollectionOffer} from "../loans/direct/loanTypes/DirectLoanFixedCollectionOffer.sol";
import {DirectLoanCoordinator, IDirectLoanCoordinator} from "../loans/direct/DirectLoanCoordinator.sol";
import {Flashloan} from "./flashloan/Flashloan.sol";
import {NftReceiver} from "../utils/NftReceiver.sol";
import {INftWrapper} from "../interfaces/INftWrapper.sol";
import {IPermittedNFTs} from "../interfaces/IPermittedNFTs.sol";
import {SwapFlashloanWETH} from "./SwapFlashloanWETH.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title  Refinancing
 * @author NFTfi
 * @notice
 */

/**
 * @title Refinancing
 *
 * @dev This smart contract is designed to manage the process of loan refinancing.
 * It allows borrowers to replace their current loans with new ones that have more favorable terms.
 * Each loan is identified by a unique identifier and associated with a refinanceable contract,
 * enabling tracking and management of loan refinancing details.
 *
 * @author NFTfi
 */
contract Refinancing is
    RefinancingAdapterRegistry,
    Flashloan,
    SwapFlashloanWETH,
    NftReceiver,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // solhint-disable-next-line immutable-vars-naming
    INftfiHub public immutable hub;
    address public targetLoanFixedOfferContract;
    address public targetLoanCollectionOfferContract;

    enum TargetLoanType {
        LOAN_OFFER,
        COLLECTION_OFFER,
        COLLECTION_RANGE_OFFER
    }

    /**
     * @notice Struct to hold data necessary for a refinancing operation.
     *
     * @param loanIdentifier Numeric identifier of the loan to be refinanced.
     * @param refinanceableContract Address of the contract that supports the refinancing.
     */
    struct RefinancingData {
        uint256 loanIdentifier;
        address refinanceableContract;
    }

    uint32 private latestRefinancedLoanId;

    event Refinanced(uint256 indexed oldLoanId, uint32 indexed newLoanId);

    error callerNotFlashloanContract();
    error flashloanInitiatorNotThisContract();
    error callerNotBorrowerOfOldLoan();
    error collateralNotOwned();
    error denominationMismatch();
    error unsupportedCollateral();
    error wrongTargetLoanType();

    /**
     * @notice Sets the admin of the contract.
     * Initializes `contractTypes` with a batch of loan types. Sets `NftfiHub`.
     * Initializes RefinancingAdapterRegistry and Flashloan contracts
     *
     * @param  _nftfiHub - Address of the NftfiHub contract
     * @param _targetLoanFixedOfferContract - Address of the target loan contract
     * @param _targetLoanCollectionOfferContract - Address of the target loan contract
     * @param _admin - Initial admin of this contract.
     * @param _definedRefinanceableTypes - Array of defined refinancing types
     * @param _refinancingAdapters - Array of addresses of the refinancing adapters
     * @param _refinanceableTypes - Array of refinancing types
     * @param _refinanceableContracts - Array of addresses of the refinancing contracts
     * @param _soloMargin - Address of the solo margin contract for flashloans
     * @param _flashloanFee - Fee for using a flashloan
     */
    constructor(
        address _nftfiHub,
        address _targetLoanFixedOfferContract,
        address _targetLoanCollectionOfferContract,
        address _admin,
        string[] memory _definedRefinanceableTypes,
        address[] memory _refinancingAdapters,
        string[] memory _refinanceableTypes,
        address[] memory _refinanceableContracts,
        address _soloMargin,
        uint256 _flashloanFee,
        SwapConstructorParams memory _swapContructorParams
    )
        RefinancingAdapterRegistry(
            _admin,
            _definedRefinanceableTypes,
            _refinancingAdapters,
            _refinanceableTypes,
            _refinanceableContracts
        )
        Flashloan(_soloMargin, _flashloanFee)
        SwapFlashloanWETH(_swapContructorParams)
    {
        hub = INftfiHub(_nftfiHub);
        targetLoanFixedOfferContract = _targetLoanFixedOfferContract;
        targetLoanCollectionOfferContract = _targetLoanCollectionOfferContract;
    }

    /**
     * @notice Function that's called back when flashloan is executed.
     * Decodes the data returned by the flashloan, then calls the internal
     * `_refinanceFlashloanCallback` function.
     * DyDx flashloan interface expects this function to exist
     *
     * this function is only the entry point of the operations happening in the callback,
     * it also serves to decode the callback data,
     * the main logic is implemented in _refinanceFlashloanCallback()
     *
     * @param _data - Byte array of data returned by the flashloan
     */
    function callFunction(address sender, AccountInfo memory, bytes memory _data) external override {
        if (address(soloMargin) != msg.sender) revert callerNotFlashloanContract();
        if (sender != address(this)) revert flashloanInitiatorNotThisContract();

        (
            address borrower,
            address payOffToken,
            uint256 payOffAmount,
            bool swapping,
            TargetLoanType targetLoanType,
            RefinancingData memory refinancingData,
            LoanData.Offer memory offer,
            LoanData.CollectionIdRange memory idRange,
            LoanData.Signature memory lenderSignature,
            LoanData.BorrowerSettings memory borrowerSettings
        ) = abi.decode(
                _data,
                (
                    address,
                    address,
                    uint256,
                    bool,
                    TargetLoanType,
                    RefinancingData,
                    LoanData.Offer,
                    LoanData.CollectionIdRange,
                    LoanData.Signature,
                    LoanData.BorrowerSettings
                )
            );

        _refinanceFlashloanCallback(
            borrower,
            payOffToken,
            payOffAmount,
            swapping,
            targetLoanType,
            refinancingData,
            offer,
            idRange,
            lenderSignature,
            borrowerSettings
        );
    }

    /**
     * @notice External function for refinancing a regular (non-collaction offer) loan,
     * sets targetType, and calls the internal _refinance(...) function
     *
     * @param _refinancingData - Data related to the refinancing loan
     * @param _offer - The loan offer details
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function refinanceLoan(
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) external {
        TargetLoanType targetLoanType = TargetLoanType.LOAN_OFFER;
        LoanData.CollectionIdRange memory idRange;
        _refinance(targetLoanType, _refinancingData, _offer, idRange, _lenderSignature, _borrowerSettings);
    }

    /**
     * @notice External function for refinancing a collaction offer loan,
     * sets targetType, and calls the internal _refinance(...) function
     *
     * @param _refinancingData - Data related to the refinancing loan
     * @param _offer - The loan offer details
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function refinanceCollectionOfferLoan(
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) external {
        TargetLoanType targetLoanType = TargetLoanType.COLLECTION_OFFER;
        LoanData.CollectionIdRange memory idRange;
        _refinance(targetLoanType, _refinancingData, _offer, idRange, _lenderSignature, _borrowerSettings);
    }

    /**
     * @notice External function for refinancing a collaction offer loan with id ranges,
     * sets targetType, and calls the internal _refinance(...) function
     *
     * @param _refinancingData - Data related to the refinancing loan
     * @param _offer - The loan offer details
     * @param _idRange - id range of collateral
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function refinanceCollectionRangeOfferLoan(
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.CollectionIdRange memory _idRange,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) external {
        TargetLoanType targetLoanType = TargetLoanType.COLLECTION_RANGE_OFFER;
        _refinance(targetLoanType, _refinancingData, _offer, _idRange, _lenderSignature, _borrowerSettings);
    }

    /**
     * @notice Internal function for initiating the loan refinance process.
     * Initiated by the borrower of the old refinancable if applicable and the new loan
     * From the standpoint of the lender this whole process can just be a regular loan,
     * the only caveat is that the collateral is locked in some refinancable protocol (loan, market).
     * If the old refinancable is a loan, borrower role transfer has to be approved
     * (eg erc-721 approve for obligation receipt) to this contract beforehand.
     * Checks the terms of the refinancing offer, verifies the borrower of the old loan,
     * pays off the old loan, creates a new loan offer and mints an Obligation Receipt Token.
     *
     * @param _targetLoanType - type of the refinancing target (enum)
     * @param _refinancingData - Data related to the refinancing loan
     * @param _offer - The loan offer details
     * @param _idRange - id range of collateral (only used if ranged type target loan)
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function _refinance(
        TargetLoanType _targetLoanType,
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.CollectionIdRange memory _idRange,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal whenNotPaused nonReentrant {
        address borrower;
        address payOffToken;
        uint256 flashloanAmount;
        bool swapping;

        {
            address refinancingAdapter = getRefinancingAdapter(_refinancingData.refinanceableContract);

            borrower = _getBorrowerAddress(
                refinancingAdapter,
                _refinancingData.refinanceableContract,
                _refinancingData.loanIdentifier
            );

            if (borrower != address(0)) {
                if (borrower != msg.sender) revert callerNotBorrowerOfOldLoan();
            } else {
                // in case of non loan refinancables, like opensea we dont need to check
                borrower = msg.sender;
            }

            uint256 payOffAmount;

            (payOffToken, payOffAmount) = _getPayoffDetails(
                refinancingAdapter,
                _refinancingData.refinanceableContract,
                _refinancingData.loanIdentifier
            );

            if (payOffToken != _offer.loanERC20Denomination) revert denominationMismatch();

            // take over old loan
            _transferBorrowerRole(
                refinancingAdapter,
                _refinancingData.refinanceableContract,
                _refinancingData.loanIdentifier
            );

            // if we have to swap tokens, to get a flashloan (no flashloan fot wstETH)
            (swapping, flashloanAmount) = _checkIfSwapNeededAndGetFlashloanParamters(payOffToken, payOffAmount);
        }

        {
            // take out flashloan
            // this will call back to callFunction()
            // inside callback:
            //   - pay off old loan
            //   - check collateral
            //   - start new loan
            _flashLoan(
                borrower,
                payOffToken,
                flashloanAmount,
                swapping,
                _targetLoanType,
                _refinancingData,
                _offer,
                _idRange,
                _lenderSignature,
                _borrowerSettings
            );
            // pay off flashloan (happens impicitly with a tranferFrom)
        }
        {
            uint256 refinancingSurplus = IERC20(payOffToken).balanceOf(address(this));
            if (refinancingSurplus > 0) {
                IERC20(payOffToken).safeTransfer(borrower, refinancingSurplus);
            }
        }

        emit Refinanced(_refinancingData.loanIdentifier, latestRefinancedLoanId);

        _mintAndSendNewLoanObligationReceipt(borrower, _targetLoanType);
    }

    /**
     * @dev Callback function that executes the core logic of refinancing after obtaining a flashloan.
     * This includes paying off the old loan, validating ownership of the collateral,
     * and creating a new loan. The function handles token swaps if necessary and ensures
     * the flashloan is paid off with the appropriate fees.
     *
     * @param _borrower Address of the borrower initiating the refinance.
     * @param _payOffToken Address of the token used to pay off the old loan.
     * @param _flashloanAmount Amount of the flashloan taken out for refinancing.
     * @param _swapping Indicates whether token swapping is needed during the refinancing process.
     * @param _refinancingData Struct containing data relevant to the refinancing operation.
     * @param _offer Details of the new loan offer being initiated.
     * @param _lenderSignature Signature of the lender of the new loan.
     * @param _borrowerSettings Settings related to the borrower for the new loan.
     */
    function _refinanceFlashloanCallback(
        address _borrower,
        address _payOffToken,
        uint256 _flashloanAmount,
        bool _swapping,
        TargetLoanType _targetLoanType,
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.CollectionIdRange memory _idRange,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal {
        address refinancingAdapter = getRefinancingAdapter(_refinancingData.refinanceableContract);

        {
            (address payBackToken, uint256 payBackAmount) = _getPayoffDetails(
                refinancingAdapter,
                _refinancingData.refinanceableContract,
                _refinancingData.loanIdentifier
            );

            if (_swapping) {
                _swapFromWeth(_payOffToken, payBackAmount);
            }

            // pay off old loan
            _payOffRefinancable(
                refinancingAdapter,
                _refinancingData.refinanceableContract,
                _refinancingData.loanIdentifier,
                payBackToken,
                payBackAmount
            );
        }

        // check collateral
        (address collateralContract, uint256 collateralId) = _getCollateral(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier
        );

        if (!_isNFTOwner(collateralContract, collateralId, address(this))) revert collateralNotOwned();

        // check if we are in deficit and get it from the borrower in that case
        _checkAndTransferDeficit(_borrower, _payOffToken, _flashloanAmount, _offer, _swapping);

        //approve nft to target loan to create the new loan
        _approveNFT(_getTargetLoanContract(_targetLoanType), collateralContract, collateralId);

        // start new loan
        latestRefinancedLoanId = _chooseAndStartLoan(
            _targetLoanType,
            _offer,
            _idRange,
            _lenderSignature,
            _borrowerSettings
        );

        if (_swapping) {
            _swapToWeth(_payOffToken, _flashloanAmount + flashloanFee);
            // we have to re-approve to soloMargin
            IERC20(wethAddress).approve(address(soloMargin), _flashloanAmount + flashloanFee);
        }
    }

    /**
     * @notice gets contract address of the target loan based on the _targetLoanType
     *
     * @param _targetLoanType - type of the refinancing target (enum)
     */
    function _getTargetLoanContract(TargetLoanType _targetLoanType) internal view returns (address) {
        if (_targetLoanType == TargetLoanType.LOAN_OFFER) {
            return targetLoanFixedOfferContract;
        } else if (_targetLoanType == TargetLoanType.COLLECTION_OFFER) {
            return targetLoanCollectionOfferContract;
        } else if (_targetLoanType == TargetLoanType.COLLECTION_RANGE_OFFER) {
            return targetLoanCollectionOfferContract;
        } else {
            revert wrongTargetLoanType();
        }
    }

    /**
     * @notice gets contract address of the target loan based on the _targetLoanType and starts the loan
     *
     * @param _targetLoanType - type of the refinancing target (enum)
     * @param _offer - The loan offer details
     * @param _idRange - id range of collateral (only used if ranged type target loan)
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function _chooseAndStartLoan(
        TargetLoanType _targetLoanType,
        LoanData.Offer memory _offer,
        LoanData.CollectionIdRange memory _idRange,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal returns (uint32 loanId) {
        if (_targetLoanType == TargetLoanType.LOAN_OFFER) {
            loanId = _startLoan(_offer, _lenderSignature, _borrowerSettings);
        } else if (_targetLoanType == TargetLoanType.COLLECTION_OFFER) {
            loanId = _startCollectionOfferLoan(_offer, _lenderSignature, _borrowerSettings);
        } else if (_targetLoanType == TargetLoanType.COLLECTION_RANGE_OFFER) {
            loanId = _startCollectionRangeOfferLoan(_offer, _idRange, _lenderSignature, _borrowerSettings);
        } else {
            revert wrongTargetLoanType();
        }
    }

    /**
     * @notice initiates a regular (non-collaction offer) loan
     *
     * @param _offer - The loan offer details
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function _startLoan(
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal returns (uint32 loanId) {
        loanId = DirectLoanFixedOffer(targetLoanFixedOfferContract).acceptOffer(
            _offer,
            _lenderSignature,
            _borrowerSettings
        );
    }

    /**
     * @notice initiates a collaction offer loan
     *
     * @param _offer - The loan offer details
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function _startCollectionOfferLoan(
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal returns (uint32 loanId) {
        DirectLoanFixedCollectionOffer directLoanCollectionOffer = DirectLoanFixedCollectionOffer(
            targetLoanCollectionOfferContract
        );
        directLoanCollectionOffer.acceptCollectionOffer(_offer, _lenderSignature, _borrowerSettings);
        loanId = DirectLoanCoordinator(
            directLoanCollectionOffer.hub().getContract(directLoanCollectionOffer.LOAN_COORDINATOR())
        ).totalNumLoans();
    }

    /**
     * @notice initiates a collaction offer loan with ranges
     *
     * @param _offer - The loan offer details
     * @param _idRange - id range of collateral (only used if ranged type target loan)
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function _startCollectionRangeOfferLoan(
        LoanData.Offer memory _offer,
        LoanData.CollectionIdRange memory _idRange,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal returns (uint32 loanId) {
        DirectLoanFixedCollectionOffer directLoanCollectionOffer = DirectLoanFixedCollectionOffer(
            targetLoanCollectionOfferContract
        );
        directLoanCollectionOffer.acceptCollectionOfferWithIdRange(
            _offer,
            _idRange,
            _lenderSignature,
            _borrowerSettings
        );
        loanId = DirectLoanCoordinator(
            directLoanCollectionOffer.hub().getContract(directLoanCollectionOffer.LOAN_COORDINATOR())
        ).totalNumLoans();
    }

    /**
     * @notice Checks if the flashloan payoff amount in the loan token is greater than the loan principal amount
     *         and transfers the deficit from the borrower to the contract.
     * @dev Used in the process of refinancing loans to handle the difference between the flashloan amount
     *      and the actual loan payoff amount.
     * @param _borrower Address of the borrower who needs to cover the deficit if any.
     * @param _payOffToken Address of the token that is used to pay off the loan.
     * @param _flashloanAmount The amount of tokens taken as a flashloan that needs to be covered.
     * @param _offer The loan offer data containing the principal amount of the loan.
     * @param _swapping A boolean indicating whether a swap operation is required.
     */
    function _checkAndTransferDeficit(
        address _borrower,
        address _payOffToken,
        uint256 _flashloanAmount,
        LoanData.Offer memory _offer,
        bool _swapping
    ) internal {
        uint256 flashloanPayoffAmountInLoanToken = _calculateFlashloanPayoffAmountInLoanToken(
            _payOffToken,
            _flashloanAmount,
            _swapping
        );
        if (flashloanPayoffAmountInLoanToken > _offer.loanPrincipalAmount) {
            uint256 refinancingDeficit = (flashloanPayoffAmountInLoanToken) - _offer.loanPrincipalAmount;
            IERC20(_payOffToken).safeTransferFrom(_borrower, address(this), refinancingDeficit);
        }
    }

    /**
     * @notice Calculates the flashloan payoff amount in the loan token.
     * @dev Considers whether a token swap is necessary due to differing token types for repayment.
     * @param _payOffToken Address of the token that is used to pay off the loan.
     * @param _flashloanAmount The amount of the loan taken as a flashloan.
     * @param _swapping A boolean indicating whether a token swap is needed.
     * @return flashloanPayoffAmountInLoanToken The calculated amount that must be paid off in the loan token.
     */
    function _calculateFlashloanPayoffAmountInLoanToken(
        address _payOffToken,
        uint256 _flashloanAmount,
        bool _swapping
    ) internal returns (uint256 flashloanPayoffAmountInLoanToken) {
        if (_swapping) {
            flashloanPayoffAmountInLoanToken = getTokenAmountNeeded(_payOffToken, _flashloanAmount + flashloanFee);
        } else {
            flashloanPayoffAmountInLoanToken = _flashloanAmount + flashloanFee;
        }
    }

    /**
     * @notice Determines if a token swap is needed for the flashloan repayment and calculates the flashloan amount.
     * @dev If the payoff token is not flashloanable, a swap to WETH is needed.
     * @param _payOffToken Address of the token to be used for paying off the loan.
     * @param _payOffAmount The amount needed to pay off the loan.
     * @return swapping Boolean indicating if a token swap is required.
     * @return flashloanAmount The amount required for the flashloan, considering any needed swap.
     */
    function _checkIfSwapNeededAndGetFlashloanParamters(
        address _payOffToken,
        uint256 _payOffAmount
    ) internal returns (bool swapping, uint256 flashloanAmount) {
        if (!tokenFlashloanble[_payOffToken]) {
            swapping = true;
            flashloanAmount = getWethAmountNeeded(_payOffToken, _payOffAmount); //swap fees included
        } else {
            swapping = false;
            flashloanAmount = _payOffAmount;
        }
    }

    /**
     * @notice Mints a new loan obligation receipt NFT and sends it to the borrower.
     * @dev The NFT represents the borrower's obligation after a loan has been refinanced.
     * @param _borrower Address of the borrower to whom the obligation receipt NFT will be sent.
     */
    function _mintAndSendNewLoanObligationReceipt(address _borrower, TargetLoanType _targetLoanType) internal {
        DirectLoanFixedOffer(_getTargetLoanContract(_targetLoanType)).mintObligationReceipt(latestRefinancedLoanId);
        DirectLoanFixedOffer directLoanFixedOffer = DirectLoanFixedOffer(_getTargetLoanContract(_targetLoanType));
        IDirectLoanCoordinator coordinator = IDirectLoanCoordinator(
            directLoanFixedOffer.hub().getContract(directLoanFixedOffer.LOAN_COORDINATOR())
        );
        uint64 smartNftId = coordinator.getLoanData(latestRefinancedLoanId).smartNftId;
        IERC721 obligationReceiptToken = IERC721(coordinator.obligationReceiptToken());
        obligationReceiptToken.safeTransferFrom(address(this), _borrower, smartNftId);
    }

    /**
     * @notice Transfers the role of borrower to a new borrower.
     * (only applicable to loan type refinancables, not markets)
     * This is a call to the adapter, which handles several types of refinancables trough an adapter
     *
     * @param _refinancingAdapter - Address of the refinancing adapter contract
     * @param _refinanceableContract - Address of the refinanceable contract
     * @param _loanIdentifier - Identifier of the loan
     */
    function _transferBorrowerRole(
        address _refinancingAdapter,
        address _refinanceableContract,
        uint256 _loanIdentifier
    ) private {
        Address.functionDelegateCall(
            _refinancingAdapter,
            abi.encodeWithSelector(
                IRefinancingAdapter(_refinancingAdapter).transferBorrowerRole.selector,
                _refinanceableContract,
                _loanIdentifier
            ),
            "transferBorrowerRole error"
        );
    }

    /**
     * @notice Pays back the refinancable
     * This is a call to the adapter, which handles several types of refinancables trough an adapter
     *
     * @param _refinancingAdapter - Address of the refinancing adapter contract
     * @param _refinanceableContract - Address of the refinanceable contract
     * @param _loanIdentifier - Identifier of the loan
     * @param _payBackToken - Address of the token used for paying back
     * @param _payBackAmount - The amount required to pay back the loan
     */
    function _payOffRefinancable(
        address _refinancingAdapter,
        address _refinanceableContract,
        uint256 _loanIdentifier,
        address _payBackToken,
        uint256 _payBackAmount
    ) private {
        Address.functionDelegateCall(
            _refinancingAdapter,
            abi.encodeWithSelector(
                IRefinancingAdapter(_refinancingAdapter).payOffRefinancable.selector,
                _refinanceableContract,
                _loanIdentifier,
                _payBackToken,
                _payBackAmount
            ),
            "payBackloan error"
        );
    }

    /**
     * @notice Retrieves the borrower's address of a specific refinancable.
     * (only applicable to loan type refinancables, not markets)
     * This is a call to the adapter, which handles several types of refinancables trough an adapter
     *
     * @param _refinancingAdapter - Address of the refinancing adapter contract
     * @param _refinanceableContract - Address of the refinanceable contract
     * @param _loanIdentifier - Identifier of the loan
     * @return Address of the borrower
     */
    function _getBorrowerAddress(
        address _refinancingAdapter,
        address _refinanceableContract,
        uint256 _loanIdentifier
    ) private returns (address) {
        bytes memory returnData = Address.functionDelegateCall(
            _refinancingAdapter,
            abi.encodeWithSelector(
                IRefinancingAdapter(_refinancingAdapter).getBorrowerAddress.selector,
                _refinanceableContract,
                _loanIdentifier
            ),
            "getBorrowerAddress error"
        );

        return abi.decode(returnData, (address));
    }

    /**
     * @notice Retrieves the collateral details of a specific refinancable.
     * This is a call to the adapter, which handles several types of refinancables trough an adapter
     *
     * @param _refinancingAdapter - Address of the refinancing adapter contract
     * @param _refinanceableContract - Address of the refinanceable contract
     * @param _loanIdentifier - Identifier of the loan
     * @return Address of the collateral contract, Identifier of the collateral
     */
    function _getCollateral(
        address _refinancingAdapter,
        address _refinanceableContract,
        uint256 _loanIdentifier
    ) private returns (address, uint256) {
        bytes memory returnData = Address.functionDelegateCall(
            _refinancingAdapter,
            abi.encodeWithSelector(
                IRefinancingAdapter(_refinancingAdapter).getCollateral.selector,
                _refinanceableContract,
                _loanIdentifier
            ),
            "getCollateral error"
        );

        return abi.decode(returnData, (address, uint256));
    }

    /**
     * @notice Retrieves the details related to the payoff of a specific refinancable, the payment token and amount
     * This is a call to the adapter, which handles several types of refinancables trough an adapter
     *
     * @param _refinancingAdapter - Address of the refinancing adapter contract
     * @param _refinanceableContract - Address of the refinanceable contract
     * @param _loanIdentifier - Identifier of the loan
     * @return Address of the payoff token, Amount required to pay off the loan
     */
    function _getPayoffDetails(
        address _refinancingAdapter,
        address _refinanceableContract,
        uint256 _loanIdentifier
    ) private returns (address, uint256) {
        bytes memory returnData = Address.functionDelegateCall(
            _refinancingAdapter,
            abi.encodeWithSelector(
                IRefinancingAdapter(_refinancingAdapter).getPayoffDetails.selector,
                _refinanceableContract,
                _loanIdentifier
            ),
            "getPayoffDetails error"
        );

        return abi.decode(returnData, (address, uint256));
    }

    /**
     * @dev Checks if a specified address is the owner of an NFT trough the NFT adaptor.
     *
     * @param _nftCollateralContract - The contract address of the NFT.
     * @param _nftCollateralId - The token ID of the NFT.
     * @param _owner - The address to check ownership against.
     *
     * @return bool - Returns true if the specified address is the owner of the NFT.
     */
    function _isNFTOwner(
        address _nftCollateralContract,
        uint256 _nftCollateralId,
        address _owner
    ) internal returns (bool) {
        address nftCollateralWrapper = _getWrapper(_nftCollateralContract);

        bytes memory result = Address.functionDelegateCall(
            nftCollateralWrapper,
            abi.encodeWithSelector(
                INftWrapper(nftCollateralWrapper).isOwner.selector,
                _owner,
                _nftCollateralContract,
                _nftCollateralId
            ),
            "NFT ownership check not successful"
        );

        return abi.decode(result, (bool));
    }

    /**
     * @dev Approves an NFT to be used by another address trough the NFT adaptor.
     *
     * @param _to - The address to approve to transfer or manage the NFT.
     * @param _nftCollateralContract - The contract address of the NFT.
     * @param _nftCollateralId - The token ID of the NFT.
     *
     * @return bool - Returns true if the approval was successful.
     */
    function _approveNFT(
        address _to,
        address _nftCollateralContract,
        uint256 _nftCollateralId
    ) internal returns (bool) {
        address nftCollateralWrapper = _getWrapper(_nftCollateralContract);

        bytes memory result = Address.functionDelegateCall(
            nftCollateralWrapper,
            abi.encodeWithSelector(
                INftWrapper(nftCollateralWrapper).approveNFT.selector,
                _to,
                _nftCollateralContract,
                _nftCollateralId
            ),
            "NFT not successfully approved"
        );

        return abi.decode(result, (bool));
    }

    /**
     * @dev Checks that the collateral is a supported contracts and returns what wrapper to use for the loan's NFT
     * collateral contract.
     *
     * @param _nftCollateralContract - The address of the the NFT collateral contract.
     *
     * @return Address of the NftWrapper to use for the loan's NFT collateral.
     */
    function _getWrapper(address _nftCollateralContract) internal view returns (address) {
        return IPermittedNFTs(hub.getContract(ContractKeys.PERMITTED_NFTS)).getNFTWrapper(_nftCollateralContract);
    }

    /**
     * @dev Checks that the collateral is a supported contracts and returns the collateral permit type
     *
     * @param _nftCollateralContract - The address of the the NFT collateral contract.
     *
     * @return Address of the NftWrapper to use for the loan's NFT collateral.
     */
    function _getPermit(address _nftCollateralContract) internal view returns (bytes32) {
        return IPermittedNFTs(hub.getContract(ContractKeys.PERMITTED_NFTS)).getNFTPermit(_nftCollateralContract);
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
     * @dev Sets the fee for flash loans.
     * @param _flashloanFee The fee percentage for flash loans.
     */
    function setFlashloanFee(uint256 _flashloanFee) public onlyOwner {
        flashloanFee = _flashloanFee;
    }

    /**
     * @dev Sets the target loan contract address
     * @param _targetLoanFixedOfferContract The address of the target loan contract.
     */
    function setTargetLoanFixedOfferContract(address _targetLoanFixedOfferContract) public onlyOwner {
        targetLoanFixedOfferContract = _targetLoanFixedOfferContract;
    }

    /**
     * @dev Sets the target loan collection offer contract address
     * @param _targetLoanCollectionOfferContract The address of the target loan contract.
     */
    function settargetLoanCollectionOfferContract(address _targetLoanCollectionOfferContract) public onlyOwner {
        targetLoanCollectionOfferContract = _targetLoanCollectionOfferContract;
    }

    /**
     * @dev Sets the swap fee rates for multiple supported tokens in batch.
     * @param _supportedTokens An array of addresses of the supported tokens.
     * @param _swapFeeRates An array of corresponding swap fee rates for each supported token.
     */
    function setSupportedTokenSwapFeeRates(
        address[] memory _supportedTokens,
        uint24[] memory _swapFeeRates
    ) external onlyOwner {
        _setSupportedTokenFeeRates(_supportedTokens, _swapFeeRates);
    }

    /**
     * @dev Sets the swap fee rate for a single supported token.
     * @param _supportedToken The address of the supported token.
     * @param _swapFeeRate The swap fee rate for the specified supported token.
     */
    function setSupportedTokenSwapFeeRate(address _supportedToken, uint24 _swapFeeRate) external onlyOwner {
        _setSupportedTokenFeeRate(_supportedToken, _swapFeeRate);
    }
}
