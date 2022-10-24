# NFTfi V2 DirectLoanFixedOffer

* rinkeby: 0x33e75763f3705252775c5aeed92e5b4987622f44
* mainnet: 0xf896527c49b44aab3cf22ae356fa3af8e331f280

Redeployed a clone contract of `DirectLoanFixedOffer` on Thu 14 Oct 2022,
`DirectLoanFixedOfferRedeploy`: 

* Goerli - 0x77097f421CEb2454eB5F77898d25159ff3C7381d
* mainnet - 0x8252Df1d8b29057d1Afe3062bf5a64D503152BC8

This contract manages the ability to create NFT-backed peer-to-peer loans with fixed interest rate i.e. where the borrower pays the full interest amount regardless of whether they repay early or not.

## Creating a new loan

### Preparations

Before creating a new loan, the borrower and lender need to do the following:

* the **borrower** must call `someNft.approveAll(DirectLoanFixedOffer)` to allow the NFTfi loan contract to move their NFT's on their behalf

* the **lender** must call `erc20Contract.approve(DirectLoanFixedOffer)` to allow the NFTfi loan contract to move the lender's ERC20 tokens on their behalf, where `erc20Contract` refers to the loan denomination (e.g. WETH or DAI)

* the **lender** must sign an off-chain message that includes all the loan terms (see the `LoanData` section)

### Accepting the Offer

The borrower calls `acceptOffer` to accept the loan terms represented by the offer and enter into the loan.

#### 1. NFT moved into escrow

The borrower's NFT is transferred into escrow with the loan contract for the duration of the loan.

#### 2. Loan principal transferred

The loan principal (in the specified ERC20 currency) is transferred from lender to borrower.

#### 3. Promissory Note

For all new loans a NFTfi Promissory Note (a ERC721 NFT in itself) is issued to the lender. This NFT represents the right to either the principal-plus-interest (on repayment) or the
NFT collateral (on loan default). 

If the Promissory Note is transferred/sold by the lender to another holder, the rights to the principal or to foreclose are also transferred. That is, after a loan is created, the lender is defined as the owner of the Promissory Note.

#### 4. Obligation Receipt

For new loans, a NFTfi Obligation Receipt is optionally available to the borrower, who can mint it at any time while the loan is active. This NFT represents the right to repay the loan and receive the collateral NFT.

```solidity
// IDirectLoanCoordinator
function mintObligationReceipt(uint32 _loanId, address _borrower)
```

The `_borrower` parameter refers to the original borrower that entered into the loan.
If the Obligation Receipt is transferred/sold by the borrower to another holder, the right to repay the loans and receive the collateral are also transferred.

That is, after a loan is created and an Obligation Receipt is minted, the borrower is defined as the owner of the Obligation Receipt. In the case of the receipt not being minted, the original borrower remains the borrower.

### acceptOffer()

This function is called by the borrower to accept a lender's off-chain signed offer.

Only the borrower can call `acceptOffer`. The borrower is specified in the loan terms signed by the lender.

Since the borrower must accept the offer, there is no need for a signature from them. 

```solidity
acceptOffer(
	struct LoanData.Offer _offer, 
	struct LoanData.Signature _signature, 
	struct LoanData.BorrowerSettings _borrowerSettings
)
```

* **struct LoanData.Offer**: the offer made by the lender
* **struct LoanData.Signature**: the components of the lender's signature
* **struct LoanData.BorrowerSettings**: additional borrower settings for accepting an offer

#### Event

Fired whenever a borrower creates a loan by calling `acceptOffer()`.

```solidity
event LoanStarted(
    uint32 indexed loanId,
    address indexed borrower,
    address indexed lender,
    LoanTerms loanTerms,
    LoanExtras loanExtras
);
```

* **loanId** - unique identifier for a loan, sourced from the Loan Coordinator.
* **borrower** - the address of the borrower
* **lender** - the address of the lender. The lender can change their address by transferring the Promissory Note that they received when the loan began.
* **loanTerms** - captures the terms of a loan and the borrower
* **loanExtras** - includes referral and revenue share related data

## Resolving a loan

A loan can be resolved either through repayment or foreclosure. 

Any time before repayment or foreclosure, the lender and borrower can renegotiate the loan terms.

### paybackLoan()

```solidity
function payBackLoan(
	uint32 _loanId
)

```

* **loanId** - unique identifier for a loan

A loan can be repaid anytime before loan expiry, by calling `payBackLoan`. Typically the borrower will call this function, although any other party can do so. The repayment amount will be transferred from whoever calls the function.

On loan repayment, the loan contract will do the following:

* transfer the loan principal-plus-interest from caller to lender
* transfer the NFT collateral from escrow back to the borrower, or to the owner of the Obligation Receipt if it had been minted by the original borrower

#### Event

This event is fired whenever a borrower successfully repays their loan, paying principal-plus-interest-minus-fee to the lender in loanERC20Denomination, paying fee to owner in  loanERC20Denomination, and receiving their NFT collateral back.

```solidity
event LoanRepaid(
    uint32 indexed loanId,
    address indexed borrower,
    address indexed lender,
    uint256 loanPrincipalAmount,
    uint256 nftCollateralId,
    uint256 amountPaidToLender,
    uint256 adminFee,
    uint256 revenueShare,
    address revenueSharePartner,
    address nftCollateralContract,
    address loanERC20Denomination
)
```

* **loanId** - unique identifier for this particular loan
* **borrower** - address of the borrower, either the original borrower or the owner of the Obligation Receipt at time of repayment
* **lender** - address of the lender, defined as the owner of the Promissory Note
* **loanPrincipalAmount** - original sum of money transferred from lender to borrower at the beginning of the loan, measured in loanERC20Denomination's smallest units
* **nftCollateralId** - tokenId within the NFTCollateralContract for the NFT being used as collateral for this loan
* **payoffAmount** amount of ERC20 that the borrower paid to the lender, measured in the smalled units of loanERC20Denomination.
* **adminFee** amount of interest paid to the contract admins, measured in the smallest units of loanERC20Denomination and equal to the adminFeeInBasisPoints
* **revenueShare** (optional) amount taken from the admin fee amount and shared with a revenue partner
* **revenueSharePartner**  - (optional) address of the partner that will receive the revenue share
* **nftCollateralContract** - contract address of the NFT collateral, this could be of type ERC721, ERC1155, CK or any future NFT type supported by NFTfi
* **loanERC20Denomination** - ERC20 contract of the currency being used as principal and interest for this loan

### liquidateOverdueLoan()

```solidity
liquidateOverdueLoan(
	uint32 _loanId
)
```

If the loan has expired (the loan duration has passed) and the loan has not been paid back yet, the loan has entered default. 

Note that only the lender can liquidate a loan.

At this point, the lender can call `liquidateOverdueLoan()` in which case the loan contract will transfer the NFT collateral to the lender (owner of the Promissory Note). This forfeits the lender's rights to the principal-plus-interest which remains with the borrower.

#### Event

This event is fired whenever the lender liquidates a defaulted loan. The lender receives the underlying NFT collateral and the borrower no longer needs to repay the loan principal-plus-interest.

```solidity
event LoanLiquidated(
    uint32 indexed loanId,
    address indexed borrower,
    address indexed lender,
    uint256 loanPrincipalAmount,
    uint256 nftCollateralId,
    uint256 loanMaturityDate,
    uint256 loanLiquidationDate,
    address nftCollateralContract
)
```

* **loanId** - unique identifier for this particular loan
* **borrower** - address of the borrower, either the original borrower or the owner of the Obligation Receipt at time of repayment
* **lender** - address of the lender, defined as the owner of the Promissory Note
* **loanPrincipalAmount** - original sum of money transferred from lender to borrower at the beginning of the loan, measured in loanERC20Denomination's smallest units
* **nftCollateralId** - tokenId within the NFTCollateralContract for the NFT being used as collateral for this loan
* **loanMaturityDate** - unix time (measured in seconds) that the loan defaulted
* **loanLiquidationDate** - unix time (measured in seconds) that liquidation occurred
* **nftCollateralContract** - contract address of the NFT collateral, this could be of type ERC721, ERC1155, CK or any future NFT type supported by NFTfi

### Renegotiating a loan

At any point before a loan has been resolved (repaid or liquidated), the borrower and lender can enter into an agreement to renegotiate the loan terms. This is possible even after default, but before the lender liquidates. 

Renegotiation requires a signature from the lender. The lender can demand a fee as part of the renegotiation.

Only the borrower (or owner of the Obligation Receipt) can call this function.

```solidity
function renegotiateLoan(
	uint32 _loanId,
	uint32 _newLoanDuration,
	uint256 _newMaximumRepaymentAmount,
	uint256 _renegotiationFee,
	uint256 _lenderNonce,
	uint256 _expiry,
	bytes memory _lenderSignature
)
```

* **loanId**: unique identifier for the loan to be renegotiated
* **_newLoanDuration** the new amount of time (in seconds) that can elapse before the loan enters default, note that this can be an extension of the original duration or a contraction (provided the new duration is not already expired)
* **_newMaximumRepaymentAmount** the new loan repayment amount, measured in the smallest units of the ERC20 currency used for the loan, can be any amount greater than the original loan principal
* **_renegotiationFee** agreed upon fee in ether that borrower pays the lender for right to renegotiation
* **_lenderNonce** - the nonce referred to here is not the same as an Ethereum account's nonce. We are referring instead to a nonce used by the lender when they sign the off-chain NFTfi renegotation terms. These nonces can be any uint256 value that the user has not previously used to sign an off-chain order. Each nonce can be used at most once per user within NFTfi 
* **_expiry** - the date when the renegotiation offer expires
* **_lenderSignature** - the ECDSA signature of the lender, obtained off-chain ahead of time, signing the following combination of parameters:
     * _loanId
     * _newLoanDuration
     * _newMaximumRepaymentAmount
     * _renegotiationFee
     * _lender
     * _nonce
     * _expiry
     * address of this loan contract
     * chainId

#### Event

This event is fired when a loan renegotiation occurs.

```solidity
event LoanRenegotiated(
        uint32 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint32 newLoanDuration,
        uint256 newMaximumRepaymentAmount,
        uint256 renegotiationFee,
        uint256 renegotiationAdminFee
    )
```

* **loanId**: unique identifier for the loan to be renegotiated
* **borrower** - address of the borrower, either the original borrower or the owner of the Obligation Receipt at time of repayment
* **lender** - address of the lender, defined as the owner of the Promissory Note
* **_newLoanDuration** the new amount of time (in seconds) that can elapse before the loan enters default, note that this can be an extension of the original duration or a contraction (provided the new duration is not already expired)
* **_newMaximumRepaymentAmount** the new loan repayment amount, measured in the smallest units of the ERC20 currency used for the loan, can be any amount greated than the original loan principal
* **_renegotiationFee** agreed upon fee in ether that borrower pays the lender for right to renegotiation, note that the frontend will have to propmt an erc20 approval from the borrower
* **renegotiationAdminFee** renegotiationFee admin portion based on determined by adminFeeInBasisPoints

## LoanData

Key Loan structs shared by Direct Loans types.

### LoanTerms

This data is saved upon loan creation.

```solidity
struct LoanTerms {
    uint256 loanPrincipalAmount;
    uint256 maximumRepaymentAmount;
    uint256 nftCollateralId;
    address loanERC20Denomination;
    uint32 loanDuration;
    uint16 loanInterestRateForDurationInBasisPoints;
    uint16 loanAdminFeeInBasisPoints;
    address nftCollateralWrapper;
    uint64 loanStartTime;
    address nftCollateralContract;
    address borrower;
}
```

* **loanPrincipalAmount** - original sum of money transferred from lender to borrower at the beginning of the loan, measured in loanERC20Denomination's smallest units
* **maximumRepaymentAmount** loan repayment amount, measured in the smallest units of the ERC20 currency used for the loan
* **nftCollateralId** - tokenId within the NFTCollateralContract for the NFT being used as collateral for this loan
* **loanERC20Denomination** - ERC20 contract of the currency being used as principal and interest for this loan
* **loanDuration** amount of time (in seconds) that can elapse before the loan enters default
* **loanInterestRateForDurationInBasisPoints** - for fixed-rate loans this value is not used and should be set to 0
* **loanAdminFeeInBasisPoints** - percentage (measured in basis points) of the interest earned that will be taken as a fee by the contract admins when the loan is repaid; stored in the loan struct and checked to prevent an attack where the contract admins could adjust the fee right before a loan is repaid, and take all of the interest earned
* **nftCollateralWrapper** - NFTfi wrapper of the NFT collateral contract; one of ERC721, ERC1155, CK
* **loanStartTime** - block.timestamp when the loan first began (measured in seconds)
* **nftCollateralContract** - contract address of the NFT collateral, this could be of type ERC721, ERC1155, CK or any future NFT type supported by NFTfi
* **borrower** - address of the borrower, either the original borrower or the owner of the Obligation Receipt at time of repayment

### LoanExtras

Some extra Loan's settings, saved upon loan creation.

```solidity
struct LoanExtras {
    address revenueSharePartner;
    uint16 revenueShareInBasisPoints;
    uint16 referralFeeInBasisPoints;
}
```

* **revenueSharePartner** - address of the partner that will receive the revenue share
* **revenueShareInBasisPoints** - percent (measured in basis points) of the admin fee amount that will be shared with a whitelisted partner
* **referralFeeInBasisPoints** - percent (measured in basis points) of the loan principal amount that will be taken as a fee to pay to the referrer, 0 if the lender is not paying referral fee

### Offer

The offer made by the lender. Used as parameter in acceptOffer (initiated by the borrower).

```solidity
struct Offer {
    uint256 loanPrincipalAmount;
    uint256 maximumRepaymentAmount;
    uint256 nftCollateralId;
    address nftCollateralContract;
    uint32 loanDuration;
    uint16 loanAdminFeeInBasisPoints;
    address loanERC20Denomination;
    address referrer;
}
```

* **loanPrincipalAmount** - original sum of money transferred from lender to borrower at the beginning of the loan, measured in loanERC20Denomination's smallest units
* **maximumRepaymentAmount** loan repayment amount, measured in the smallest units of the ERC20 currency used for the loan
* **nftCollateralId** - tokenId within the NFTCollateralContract for the NFT being used as collateral for this loan
* **nftCollateralContract** - contract address of the NFT collateral, this could be of type ERC721, ERC1155, CK or any future NFT type supported by NFTfi
* **loanDuration** amount of time (in seconds) that can elapse before the loan enters default
* **loanAdminFeeInBasisPoints** - percentage (measured in basis points) of the interest earned that will be taken as a fee by the contract admins when the loan is repaid; stored in the loan struct and checked to prevent an attack where the contract admins could adjust the fee right before a loan is repaid, and take all of the interest earned
* **loanERC20Denomination** - ERC20 contract of the currency being used as principal and interest for this loan
* **referrer** - The address of the referrer who found the lender matching the listing, a zero address to signal that there is no referrer

### Borrower Settings

Some extra parameters that the borrower needs to set when accepting an offer.

```solidity
struct BorrowerSettings {
	address revenueSharePartner;
	uint16 referralFeeInBasisPoints;
}
```

* **revenueSharePartner** - address of the partner that will receive the revenue share
* **referralFeeInBasisPoints** - percent (measured in basis points) of the loan principal amount that will be taken as a fee to pay to the referrer, 0 if the lender is not paying referral fee

### Signature

Signature related params. Used as parameter in `acceptOffer` (containing lender signature).

```solidity
struct Signature {
    uint256 nonce;
    uint256 expiry;
    address signer;
    bytes signature;
}
```

* **signer** - for `acceptOffer`, the lender address
* **nonce** - The nonce referred here is not the same as an Ethereum account's nonce.
We are referring instead to a nonce that is used by the lender or the borrower when they are first signing off-chain NFTfi orders. These nonce can be any uint256 value that the user has not previously used to sign an off-chain order. Each nonce can be used at most once per user within NFTfi, regardless of whether they are the lender or the borrower in that situation. This serves two purposes:
	- First, it prevents replay attacks where an attacker would submit a user's off-chain order more than once.
	- Second, it allows a user to cancel an off-chain order by calling NFTfi.cancelLoanCommitmentBeforeLoanHasBegun()
which marks the nonce as used and prevents any future loan from using the user's off-chain order that contains that nonce.
* **expiry** - date when the Offer signature expires
* **signature** - The ECDSA signature of the lender, obtained off-chain ahead of time, signing the following combination of parameters:
	- Lender:
		- Offer.loanPrincipalAmount
		- Offer.maximumRepaymentAmount
		- Offer.nftCollateralId
		- Offer.nftCollateralContract
		- Offer.loanDuration
		- Offer.loanAdminFeeInBasisPoints
		- Offer.loanERC20Denomination
		- Offer.referrer
		- Signature.nonce,
		- Signature.expiry,
		- Signature.signer,
		- address of the DirectLoanFixedOffer loan contract

