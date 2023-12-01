// SPDX-License-Identifier: BUSL-1.1

import "./IFlashloan.sol";
import "./ISoloMargin.sol";
import "../Refinancing.sol";
import "../../loans/direct/loanTypes/LoanData.sol";
import "../../utils/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity 0.8.19;

/**
 * @title Flashloan
 * @author NFTfi
 * @dev This contract allows for executing flash loans using the dYdX lending protocol.
 * It handles the initiation of the flash loans.
 */
abstract contract Flashloan is IFlashloan {
    // The address of the SoloMargin contract for executing flash loans.
    ISoloMargin public immutable soloMargin;

    // Mapping to keep track of tokens that can be flash loaned. (tokenAddress => isFlashloanble)
    mapping(address => bool) public tokenFlashloanble;
    // Mapping to keep track of market ids for each token. (tokenAddress => marketId)
    mapping(address => uint256) public marketIds;

    // Flash loan fee amount. Can be 0
    uint256 public flashloanFee;

    error noFlashloanForToken();

    /**
     * @dev Contract constructor that sets the SoloMargin contract and the flash loan fee.
     * @param _soloMargin The address of the SoloMargin contract. (dYdX)
     * @param _flashloanFee The amount of the flash loan fee.
     */
    constructor(address _soloMargin, uint256 _flashloanFee) {
        soloMargin = ISoloMargin(_soloMargin);
        flashloanFee = _flashloanFee;
        if (_soloMargin != address(0)) {
            _loadTokens(_soloMargin);
        }
    }

    /**
     * @dev Loads tokens that can be flash loaned from the SoloMargin contract.
     * It uses the private _loadTokens function to populate the tokenFlashloanble and marketIds mappings.
     */
    function loadTokens() public {
        _loadTokens(address(soloMargin));
    }

    /**
     * @dev Helper function that populates the tokenFlashloanble and marketIds mappings.
     * @param _soloMargin The address of the SoloMargin contract.
     */
    function _loadTokens(address _soloMargin) private {
        for (uint256 i; i <= 3; ++i) {
            address tokenAddress = ISoloMargin(_soloMargin).getMarketTokenAddress(i);
            tokenFlashloanble[tokenAddress] = true;
            marketIds[tokenAddress] = i;
        }
    }

    /**
     * @dev Initiates a flash loan operation. Constructs an
     * operations array containing Withdraw, Call, and Deposit actions.
     * Then it approves the token transfer and calls the operate function on the soloMargin contract.
     * @param _borrower The address of the borrower.
     * @param _token The token to be flash loaned.
     * @param _amount The amount to be flash loaned.
     * @param _refinancingData Data related to the refinancing operation.
     * @param _offer The loan offer details.
     * @param _lenderSignature The lender's signature for the loan.
     * @param _borrowerSettings The borrower's settings for the loan.
     */
    function _flashLoan(
        address _borrower,
        address _token,
        uint256 _amount,
        Refinancing.RefinancingData memory _refinancingData,
        LoanData.Offer memory _offer,
        LoanData.Signature memory _lenderSignature,
        LoanData.BorrowerSettings memory _borrowerSettings
    ) internal {
        /*
        The flash loan functionality in dydx is predicated by their "operate" function,
        which takes a list of operations to execute, and defers validating the state of
        things until it's done executing them.
        
        We thus create three operations, a Withdraw (which loans us the funds), a Call
        (which invokes the callFunction method on this contract), and a Deposit (which
        repays the loan, plus the 2 wei fee), and pass them all to "operate".
        
        Note that the Deposit operation will invoke the transferFrom to pay the loan 
        (or whatever amount it was initialised with) back to itself, there is no need
        to pay it back explicitly.
        
        The loan must be given as an ERC-20 token, so WETH is used instead of ETH. Other
        currencies (DAI, USDC) are also available, their index can be looked up by
        calling getMarketTokenAddress on the solo margin contract, and set as the 
        primaryMarketId in the Withdraw and Deposit definitions.
        */

        if (!tokenFlashloanble[_token]) revert noFlashloanForToken();

        uint256 primaryMarketId = marketIds[_token];

        ActionArgs[] memory operations = new ActionArgs[](3);

        operations[0] = ActionArgs({
            actionType: ActionType.Withdraw,
            accountId: 0,
            amount: AssetAmount({
                sign: false,
                denomination: AssetDenomination.Wei,
                ref: AssetReference.Delta,
                value: _amount // Amount to borrow
            }),
            primaryMarketId: primaryMarketId,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });

        operations[1] = ActionArgs({
            actionType: ActionType.Call,
            accountId: 0,
            amount: AssetAmount({
                sign: false,
                denomination: AssetDenomination.Wei,
                ref: AssetReference.Delta,
                value: 0
            }),
            primaryMarketId: primaryMarketId,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: abi.encode(_borrower, _token, _amount, _refinancingData, _offer, _lenderSignature, _borrowerSettings)
        });

        operations[2] = ActionArgs({
            actionType: ActionType.Deposit,
            accountId: 0,
            amount: AssetAmount({
                sign: true,
                denomination: AssetDenomination.Wei,
                ref: AssetReference.Delta,
                value: _amount + flashloanFee
            }),
            primaryMarketId: primaryMarketId,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });

        IERC20(_token).approve(address(soloMargin), _amount + flashloanFee);

        AccountInfo[] memory accountInfos = new AccountInfo[](1);
        accountInfos[0] = AccountInfo({owner: address(this), number: 1});

        soloMargin.operate(accountInfos, operations);
    }

    /**
     * @dev This function is called by the dYdX protocol after the loan is given.
     * It is intended to be overridden in a derived contract to implement custom logic.
     * @param sender The address initiating the call.
     * @param accountInfo Account related information.
     * @param data The data passed in the call.
     */
    function callFunction(
        address sender,
        AccountInfo memory accountInfo,
        bytes memory data
    ) external virtual override {
        // solhint-disable-previous-line no-empty-blocks
    }
}
