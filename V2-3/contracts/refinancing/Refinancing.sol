// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "../interfaces/INftfiHub.sol";
import "../utils/Ownable.sol";
import "../loans/direct/loanTypes/LoanData.sol";
import "./refinancingAdapters/RefinancingAdapterRegistry.sol";
import "./refinancingAdapters/IRefinancingAdapter.sol";
import "../loans/direct/loanTypes/DirectLoanFixedOffer.sol";
import "./flashloan/Flashloan.sol";
import "../utils/NftReceiver.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

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
contract Refinancing is RefinancingAdapterRegistry, Flashloan, NftReceiver {
    INftfiHub public immutable hub;
    address public loanContract;

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

    /**
     * @notice Sets the admin of the contract.
     * Initializes `contractTypes` with a batch of loan types. Sets `NftfiHub`.
     * Initializes RefinancingAdapterRegistry and Flashloan contracts
     *
     * @param  _nftfiHub - Address of the NftfiHub contract
     * @param _loanContract - Address of the loan contract
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
        address _loanContract,
        address _admin,
        string[] memory _definedRefinanceableTypes,
        address[] memory _refinancingAdapters,
        string[] memory _refinanceableTypes,
        address[] memory _refinanceableContracts,
        address _soloMargin,
        uint256 _flashloanFee
    )
        RefinancingAdapterRegistry(
            _admin,
            _definedRefinanceableTypes,
            _refinancingAdapters,
            _refinanceableTypes,
            _refinanceableContracts
        )
        Flashloan(_soloMargin, _flashloanFee)
    {
        hub = INftfiHub(_nftfiHub);
        loanContract = _loanContract;
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
    function callFunction(
        address,
        AccountInfo memory,
        bytes memory _data
    ) external override {
        (
            address borrower,
            address payOffToken,
            uint256 payOffAmount,
            RefinancingData memory refinancingData,
            LoanData.Offer memory offer,
            LoanData.Signature memory lenderSignature,
            LoanData.BorrowerSettings memory borrowerSettings
        ) = abi.decode(
            _data,
            (address, address, uint256, RefinancingData, LoanData.Offer, LoanData.Signature, LoanData.BorrowerSettings)
        );

        _refinanceFlashloanCallback(
            borrower,
            payOffToken,
            payOffAmount,
            refinancingData,
            offer,
            lenderSignature,
            borrowerSettings
        );
    }

    /**
     * @notice Main function for initiating the loan refinance process.
     * Initiated by the borrower of the old refinancable if applicable and the new loan
     * From the standpoint of the lender this whole process can just be a regular loan,
     * the only caveat is that the collateral is locked in some refinancable protocol (loan, market).
     * If the old refinancable is a loan, borrower role transfer has to be approved
     * (eg erc-721 approve for obligation receipt) to this contract beforehand.
     * Checks the terms of the refinancing offer, verifies the borrower of the old loan,
     * pays off the old loan, creates a new loan offer and mints an Obligation Receipt Token.
     *
     * @param _refinancingData - Data related to the refinancing loan
     * @param _offer - The loan offer details
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function refinance(
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) external {
        // check terms

        address refinancingAdapter = getRefinancingAdapter(_refinancingData.refinanceableContract);

        address borrower = _getBorrowerAddress(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier
        );

        if (borrower != address(0)) {
            require(borrower == msg.sender, "has to be borrower of old loan");
        } else {
            // in case of non loan refinancables, like opensea we dont need to check
            borrower = msg.sender;
        }

        (address payOffToken, uint256 payOffAmount) = _getPayoffDetails(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier
        );
        // take over old loan
        _transferBorrowerRole(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier
        );
        // take out flashloan
        // this will call back to callFunction()
        // inside callback:
        //   - pay off old loan
        //   - check collateral
        //   - start new loan
        _flashLoan(borrower, payOffToken, payOffAmount, _refinancingData, _offer, _lenderSignature, _borrowerSettings);
        // pay off flashloan (happens impicitly with a tranferFrom)

        uint256 refinancingSurplus = IERC20(payOffToken).balanceOf(address(this));
        if (refinancingSurplus > 0) {
            IERC20(payOffToken).transfer(borrower, refinancingSurplus);
        }

        // mint and send Obligation Receipt Token
        DirectLoanFixedOffer(loanContract).mintObligationReceipt(latestRefinancedLoanId);
        DirectLoanFixedOffer directLoanFixedOffer = DirectLoanFixedOffer(loanContract);
        IDirectLoanCoordinator coordinator = IDirectLoanCoordinator(
            directLoanFixedOffer.hub().getContract(directLoanFixedOffer.LOAN_COORDINATOR())
        );
        uint64 smartNftId = coordinator.getLoanData(latestRefinancedLoanId).smartNftId;
        IERC721 obligationReceiptToken = IERC721(coordinator.obligationReceiptToken());
        obligationReceiptToken.transferFrom(address(this), borrower, smartNftId);
    }

    /**
     * @notice Internal function that's called back when a flashloan is executed.
     * Pays off the old loan, verifies ownership of collateral, starts a new loan.
     *
     * @param _borrower - Address of the borrower
     * @param _payOffToken - Address of the token used for payoff
     * @param _payOffAmount - The amount required to pay off the loan
     * @param _refinancingData - Data related to the refinancing loan
     * @param _offer - The loan offer details
     * @param _lenderSignature - Signature of the lender
     * @param _borrowerSettings - Settings related to the borrower
     */
    function _refinanceFlashloanCallback(
        address _borrower,
        address _payOffToken,
        uint256 _payOffAmount,
        RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal {
        address refinancingAdapter = getRefinancingAdapter(_refinancingData.refinanceableContract);

        (address payBackToken, uint256 payBackAmount) = _getPayoffDetails(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier
        );

        // pay off old loan
        _payOffRefinancable(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier,
            payBackToken,
            payBackAmount
        );

        // check collateral
        (address collateralContract, uint256 collateralId) = _getCollateral(
            refinancingAdapter,
            _refinancingData.refinanceableContract,
            _refinancingData.loanIdentifier
        );
        require(address(this) == IERC721(collateralContract).ownerOf(collateralId), "collateral not owned");

        // check if we are in deficit and get it from the borrower in that case
        if (_payOffAmount + flashloanFee > _offer.loanPrincipalAmount) {
            uint256 refinancingDeficit = (_payOffAmount + flashloanFee) - _offer.loanPrincipalAmount;
            // should be borrower
            IERC20(_payOffToken).transferFrom(_borrower, address(this), refinancingDeficit);
        }

        // if _payOffToken and loanERC20Denomination, we would have
        // to convert on uniswap (or similar), could be implemented in future
        IERC20(_offer.loanERC20Denomination).approve(loanContract, _offer.loanPrincipalAmount);

        IERC721(collateralContract).approve(loanContract, collateralId);
        // start new loan
        latestRefinancedLoanId = DirectLoanFixedOffer(loanContract).acceptOffer(
            _offer,
            _lenderSignature,
            _borrowerSettings
        );
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
}
