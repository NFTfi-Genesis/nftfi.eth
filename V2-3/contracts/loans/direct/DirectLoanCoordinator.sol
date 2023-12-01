// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "../../smartNft/SmartNft.sol";
import "../../interfaces/IDirectLoanCoordinator.sol";
import "../../interfaces/INftfiHub.sol";
import "../../utils/Ownable.sol";
import "../../utils/ContractKeys.sol";

/**
 * @title  DirectLoanCoordinator
 * @author NFTfi
 * @notice This contract is in charge of coordinating the creation, disctubution and desctruction of the SmartNfts
 * related to a loan, the Promossory Note and Obligaiton Receipt.
 */
contract DirectLoanCoordinator is IDirectLoanCoordinator, Ownable {
    /* ******* */
    /* STORAGE */
    /* ******* */

    INftfiHub public immutable hub;

    /**
     * @dev For each loan type, records the address of the contract that implements the type
     */
    mapping(bytes32 => address) private typeContracts;
    /**
     * @dev reverse mapping of loanTypes - for each contract address, records the associated loan type
     */
    mapping(address => bytes32) private contractTypes;

    /**
     * @notice A continuously increasing counter that simultaneously allows every loan to have a unique ID and provides
     * a running count of how many loans have been started by this contract.
     */
    uint32 public totalNumLoans = 0;

    uint32 public smartNftIdCounter = 0;

    // The address that deployed this contract
    address private immutable _deployer;
    bool private _initialized = false;

    mapping(uint32 => Loan) private loans;

    address public override promissoryNoteToken;
    address public override obligationReceiptToken;

    /* ****** */
    /* EVENTS */
    /* ****** */

    event UpdateStatus(
        uint32 indexed loanId,
        uint64 indexed smartNftId,
        address indexed loanContract,
        StatusType newStatus
    );

    /**
     * @notice This event is fired whenever the admins register a loan type.
     *
     * @param loanType - Loan type represented by keccak256('loan type').
     * @param loanContract - Address of the loan type contract.
     */
    event TypeUpdated(bytes32 indexed loanType, address indexed loanContract);

    /**
     * @dev Function using this modifier can only be executed after this contract is initialized
     *
     */
    modifier onlyInitialized() {
        require(_initialized, "not initialized");

        _;
    }

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @notice Sets the admin of the contract.
     * Initializes `contractTypes` with a batch of loan types. Sets `NftfiHub`.
     *
     * @param  _nftfiHub - Address of the NftfiHub contract
     * @param _admin - Initial admin of this contract.
     * @param _loanTypes - Loan types represented by keccak256('loan type').
     * @param _loanContracts - The addresses of each wrapper contract that implements the loan type's behaviour.
     */
    constructor(
        address _nftfiHub,
        address _admin,
        string[] memory _loanTypes,
        address[] memory _loanContracts
    ) Ownable(_admin) {
        hub = INftfiHub(_nftfiHub);
        _deployer = msg.sender;
        _registerLoanTypes(_loanTypes, _loanContracts);
    }

    /**
     * @dev Sets `promissoryNoteToken` and `obligationReceiptToken`.
     * It can be executed once by the deployer.
     *
     * @param  _promissoryNoteToken - Promissory Note Token address
     * @param  _obligationReceiptToken - Obligaiton Recipt Token address
     */
    function initialize(address _promissoryNoteToken, address _obligationReceiptToken) external {
        require(msg.sender == _deployer, "only deployer");
        require(!_initialized, "already initialized");
        require(_promissoryNoteToken != address(0), "promissoryNoteToken is zero");
        require(_obligationReceiptToken != address(0), "obligationReceiptToken is zero");

        _initialized = true;
        promissoryNoteToken = _promissoryNoteToken;
        obligationReceiptToken = _obligationReceiptToken;
    }

    /**
     * @dev This is called by the LoanType beginning the new loan.
     * It initialize the new loan data, mints both PromissoryNote and ObligationReceipt SmartNft's and returns the
     * new loan id.
     *
     * @param _lender - Address of the lender
     * @param _loanType - The type of the loan
     */
    function registerLoan(address _lender, bytes32 _loanType) external override onlyInitialized returns (uint32) {
        address loanContract = msg.sender;

        require(getContractFromType(_loanType) == loanContract, "Caller must be registered for loan type");

        // (loanIds start at 1)
        totalNumLoans += 1;
        smartNftIdCounter += 1;

        uint64 smartNftId = uint64(uint256(keccak256(abi.encodePacked(address(this), smartNftIdCounter))));

        Loan memory newLoan = Loan({status: StatusType.NEW, loanContract: loanContract, smartNftId: smartNftId});

        // Issue an ERC721 promissory note to the lender that gives them the
        // right to either the principal-plus-interest or the collateral.
        SmartNft(promissoryNoteToken).mint(_lender, smartNftId, abi.encode(totalNumLoans));

        loans[totalNumLoans] = newLoan;

        emit UpdateStatus(totalNumLoans, smartNftId, loanContract, StatusType.NEW);

        return totalNumLoans;
    }

    function mintObligationReceipt(uint32 _loanId, address _borrower) external override onlyInitialized {
        address loanContract = msg.sender;

        require(getTypeFromContract(loanContract) != bytes32(0), "Caller must a be registered loan type");

        uint64 smartNftId = loans[_loanId].smartNftId;
        require(smartNftId != 0, "loan doesn't exist");
        require(SmartNft(promissoryNoteToken).exists(smartNftId), "Promissory note should exist");
        require(!SmartNft(obligationReceiptToken).exists(smartNftId), "Obligation r shouldn't exist");

        // Issue an ERC721 obligation receipt to the borrower that gives them the
        // right to pay back the loan and get the collateral back.
        SmartNft(obligationReceiptToken).mint(_borrower, smartNftId, abi.encode(_loanId));
    }

    function resetSmartNfts(uint32 _loanId, address _lender) external override onlyInitialized {
        address loanContract = msg.sender;
        require(getTypeFromContract(loanContract) != bytes32(0), "Caller must a be registered loan type");

        uint64 oldSmartNftId = loans[_loanId].smartNftId;
        require(oldSmartNftId != 0, "loan doesn't exist");
        require(SmartNft(promissoryNoteToken).exists(oldSmartNftId), "Promissory note should exist");

        SmartNft(promissoryNoteToken).burn(oldSmartNftId);

        // (loanIds start at 1)
        smartNftIdCounter += 1;
        uint64 newSmartNftId = uint64(uint256(keccak256(abi.encodePacked(address(this), smartNftIdCounter))));
        SmartNft(promissoryNoteToken).mint(_lender, newSmartNftId, abi.encode(_loanId));
        loans[_loanId].smartNftId = newSmartNftId;

        if (SmartNft(obligationReceiptToken).exists(oldSmartNftId)) {
            SmartNft(obligationReceiptToken).burn(oldSmartNftId);
        }
    }

    /**
     * @dev This is called by the LoanType who created the loan, when a loan is resolved whether by paying back or
     * liquidating the loan.
     * It sets the loan as `RESOLVED` and burns both PromossoryNote and ObligationReceipt SmartNft's.
     *
     * @param _loanId - Id of the loan
     */
    function resolveLoan(uint32 _loanId, bool _repaid) external override onlyInitialized {
        Loan storage loan = loans[_loanId];
        require(loan.status == StatusType.NEW, "Loan status must be New");
        require(loan.loanContract == msg.sender, "Not the same Contract that registered Loan");

        if (_repaid) {
            loan.status = StatusType.REPAID;
        } else {
            loan.status = StatusType.LIQUIDATED;
        }

        SmartNft(promissoryNoteToken).burn(loan.smartNftId);
        if (SmartNft(obligationReceiptToken).exists(loan.smartNftId)) {
            SmartNft(obligationReceiptToken).burn(loan.smartNftId);
        }

        emit UpdateStatus(_loanId, loan.smartNftId, msg.sender, loan.status);
    }

    /**
     * @dev Returns loan's data for a given id.
     *
     * @param _loanId - Id of the loan
     */
    function getLoanData(uint32 _loanId) external view override returns (Loan memory) {
        return loans[_loanId];
    }

    /**
     * @dev checks if the given id is valid for the given loan contract address
     * @param _loanId - Id of the loan
     * @param _loanContract - address og the loan contract
     */
    function isValidLoanId(uint32 _loanId, address _loanContract) external view override returns (bool validity) {
        validity = loans[_loanId].loanContract == _loanContract;
    }

    /**
     * @notice  Set or update the contract address that implements the given Loan Type.
     * Set address(0) for a loan type for un-register such type.
     *
     * @param _loanType - Loan type represented by 'loan type'.
     * @param _loanContract - The address of the wrapper contract that implements the loan type's behaviour.
     */
    function registerLoanType(string memory _loanType, address _loanContract) external onlyOwner {
        _registerLoanType(_loanType, _loanContract);
    }

    /**
     * @notice  Batch set or update the contract addresses that implement the given batch Loan Type.
     * Set address(0) for a loan type for un-register such type.
     *
     * @param _loanTypes - Loan types represented by 'loan type'.
     * @param _loanContracts - The addresses of each wrapper contract that implements the loan type's behaviour.
     */
    function registerLoanTypes(string[] memory _loanTypes, address[] memory _loanContracts) external onlyOwner {
        _registerLoanTypes(_loanTypes, _loanContracts);
    }

    /**
     * @notice This function can be called by anyone to get the contract address that implements the given loan type.
     *
     * @param  _loanType - The loan type, e.g. bytes32("DIRECT_LOAN_FIXED"), or bytes32("DIRECT_LOAN_PRO_RATED").
     */
    function getContractFromType(bytes32 _loanType) public view returns (address) {
        return typeContracts[_loanType];
    }

    /**
     * @notice This function can be called by anyone to get the loan type of the given contract address.
     *
     * @param  _loanContract - The loan contract
     */
    function getTypeFromContract(address _loanContract) public view returns (bytes32) {
        return contractTypes[_loanContract];
    }

    /**
     * @notice  Set or update the contract address that implements the given Loan Type.
     * Set address(0) for a loan type for un-register such type.
     *
     * @param _loanType - Loan type represented by 'loan type').
     * @param _loanContract - The address of the wrapper contract that implements the loan type's behaviour.
     */
    function _registerLoanType(string memory _loanType, address _loanContract) internal {
        require(bytes(_loanType).length != 0, "loanType is empty");
        bytes32 loanTypeKey = ContractKeys.getIdFromStringKey(_loanType);

        typeContracts[loanTypeKey] = _loanContract;
        contractTypes[_loanContract] = loanTypeKey;

        emit TypeUpdated(loanTypeKey, _loanContract);
    }

    /**
     * @notice  Batch set or update the contract addresses that implement the given batch Loan Type.
     * Set address(0) for a loan type for un-register such type.
     *
     * @param _loanTypes - Loan types represented by keccak256('loan type').
     * @param _loanContracts - The addresses of each wrapper contract that implements the loan type's behaviour.
     */
    function _registerLoanTypes(string[] memory _loanTypes, address[] memory _loanContracts) internal {
        require(_loanTypes.length == _loanContracts.length, "function information arity mismatch");

        for (uint256 i; i < _loanTypes.length; ++i) {
            _registerLoanType(_loanTypes[i], _loanContracts[i]);
        }
    }
}
