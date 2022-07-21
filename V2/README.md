# NFTfi V2 Introduction
   
NFTfi.v2 facilitates P2P loans using NFTs as collateral.

P2P loans are directly between a borrower and lender, where the borrower brings the NFT collateral and lender brings the liquidity.

New loan types can be added through the loan registry system. Currently deployed loan types are

* [Loan type - DirectLoanFixedOffer.md](https://github.com/NFTfi-Genesis/nftfi.eth/blob/main/V2/Loan%20type%20-%20DirectLoanFixedOffer.md)
	- the interest rate is fixed, that is, the borrower pays the full interest regardless of whether they pay early or at the latest possible time
	- the loan is initiated by the borrower when they accept the lender's offer
## Loan life cycle

Before a loan can be initiated on-chain, there are 2 off-chain steps:

### 1) Borrower lists an NFT

The borrower (NFT owner) lists the NFT as loan collateral on the NFTfi marketplace.
### 2) Lender makes an offer

Lenders(s) respond to listings with offers - one or more lenders make offers in response to a listing.

### Begin Loan - Accept offer

A borrower accepts a lender's offer and initiates a new loan.

The NFT moves into escrow and the loan principal is paid from lender to borrower.

### Allowances

For the NFTfi loan contract to be able to move the NFT into escrow on loan initiation, the borrower must approve the NFTfi contract to be able to transfer their NFT.

For the NFTfi loan contract to be able to transfer the loan principal from lender to borrower, the lender must approve the ERC20 they want to use for the loan.

Similarly, before loan repayment, the borrower must approve the ERC20 to be transferred to the lender.

### Loan NFTs

When a new loan begins, two loan NFTs are potentially issued.

The lender is issued with a Promissory Note NFT, which represents the right to the loan repayment or NFT collateral in case of non-repayment.  Whoever holds the Promissory Note at repayment will receive the loan repayment or the NFT collateral (at foreclosure).

The borrower can optionally mint an Obligation Receipt NFT, which represents the right to the NFT collateral on repayment. Whoever holds the Obligation Receipt at repayment will receive the NFT collateral on repayment.

When a loan is resolved - either through repayment or liquidation - the Promissory Note and Obligation Receipt are burned.

### Borrower repays loan

Any time before loan expiry, the borrower repays the loan principal + interest + NFTfi admin fee.

The NFT moves from escrow back to the borrower.

The admin fee is paid to the NFTfi contract and the loan principal plus interest is paid to the lender.

### Lender liquidates loan

Any time after an unpaid loan expires, the lender can foreclose the loan. 
The lender forfeits the loan principal and gets the NFT. 
In this case, no admin fee is paid to the NFTfi contract.

## Governed Variables for Fixed/Pro-rated loans

Loan types have the following governable protocol parameters:

* `maximumLoanDuration`
* `adminFeeInBasisPoints`

## Permitted NFTs and NFT Types

The NFT used as collateral can be ERC721, ERC1155 and CryptoKitties (CK).

New NFT types can be supported by registering a new wrapper contract for a new NFT type (e.g. ERC1155) and contracts of that type can be added as a permitted NFTs.

## Permitted ERC20s

The possible loan denomination ERC20s are managed by an ERC20 Permitted list. Currently NFTfi supports WETH and DAI.

## Gas Fees

Borrowers will pay gas fees for:

* approving NFTfi to interact with their NFT (once per NFT collection, except for CryptoKitties, where it must be done for each individual cat as CK isn’t fully ERC-721 compliant)
* approving the NFTfi smart contract to spend (repay) wETH or DAI for the first time (one-time transaction)
* accepting an offer
* repaying a loan

Lenders pay gas fees for:

* approving the NFTfi smart contract to spend wETH or DAI for the first time (one-time transaction)
* foreclosing an NFT in case of a borrower default

## Loan features

The following features are optional and composable (they can be arbitrarily mixed).

### Referrals

The goal of this feature is to allow borrowers to incentivise intermediaries to help them find a successful lender-match.

**The referral process**

1) the borrower specifies a referral fee (an absolute amount) as part of listing terms, to incentivise intermediaries to help them find liquidity

2) intermediaries facilitate offers from lenders and include their "referrer address" in the offer

3) when the loan begins, `loan principal - referral fee` is transferred from lender to borrower and the `referral fee` is transferred to the referrer (that is, the referral fee is paid upfront when the loan is begun - if the borrower doesn't repay and the loan is foreclosed, the referrer would have received their fee regardless)

4) upon loan repayment, the borrower repays the `(loan principal - referral fee) + referral fee + interest` (that is `loan principal + interest`) 

The referral fee is paid from borrower to referrer, the lender does not contribute at all to the referral fee.

### Revenue Sharing

The goal of this feature is to enable NFTfi to incentivise partners to bring listings to the NFTfi platform via an "originator fee".

#### Permitted Partners

Consider a partnership with a marketplace - we want to incentivise them to do NFT loans on our platform by giving them a share of admin fee on loan repayment.

First we need to permit them as partners (see `PermittedPartners.sol`) by registering them with a revenue share percentage.

#### Loans generated by revenue-sharing partners

When NFT owners want to list their NFTs as collateral for loans on some revenue sharing marketplace, they would define a listing via the marketplace dapp which will ultimately create a listing on the NFTfi platform that includes the partner's address.


From the perspective of users of marketlpace (borrowers), they are simply listing their NFTs for loans in a similar way as NFTfi users do (although the interaction starts in the marketplace dapp).

Lenders can see these listings on the NFTfi marketplace and interact with them as per usual - it makes no difference to them the the loan was sourced from another marketplace.

On loan repayment, the borrower pays the principal + interest as per usual, except that a percentage of the adminFee is paid to the partner marketplace.

### Loan re-negotiations

This feature allows borrowers and lenders to agree on changing loan duration and/or repayment amount.

Loans can be re-negotiated even after expiry e.g. a lender can agree to extend an expired loan.
Lenders can require an optional renegotiation fee, which is transferred from borrower to lender when the borrower initiates the lender-signed renegotiation. NFTfi receives a portion of the renegotiation fee (the same portion that is taken from the regular repayment interest fee, as governed by the AdminFee protocol parameter).

The first part of the process of extending a loan happens off-chain:

* via the NFTfi app, either of the borrower or lender can initiate a renegotiation, stating a new loan `Duration` and `MaxRepayment`
* the lender signs an off-chain message with: `LoanId, NewDuration, NewMaxRepayment, Expiry, Fee`

Once the borrower has this signed message from the lender (via the NFTfi app), they can initiate the renegotiation.

A renegotiation updates the state of a loan on-chain and the loan retains its original loan id.
### Loan NFT Trades

When a new loan is created, borrowers get an Obligation Receipt NFT and lenders, a Promissory Note NFT.

Lenders and borrowers are free to sell their promise/obligation to someone else on any marketplaces that permit the NFTfi loan NFTs.
