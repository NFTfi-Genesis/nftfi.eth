# NFTfi.sol

* mainnet: 0x88341d1a8f672d2780c8dc725902aae72f143b0c

Facilitates P2P NFT loans:

## Listing an NFT (Borrower)

- Borrower creates a LISTING - An NFT owner Lists an NFT as loan collateral on the NFTfi marketplace

## Making an Offer (Lender)

- LENDER(s) respond with OFFERS - one or more Lenders make Offers in response to a Listing
- NOTE: Listings and Offers happen off-chain (for Ethereum L1 contracts). Borrower and Lender off-chain signatures are then used to validate new loans

## Begin loan (Borrower)

- Borrower Accepts Offer/Begins Loan
- the Borrower accepts the Loan Terms on some Offer
- The NFT moves into escrow and the Loan Principal is paid from Lender to Borrower

## Repay loan (Borrower)

- some time before the Loan expiry, the Borrower repays the Loan Principal + Interest + Admin Fee
- the NFT moves from escrow back to the Borrower
- the Admin Fee is paid to the NFTfi contract and the Loan Principal plus Interest is paid to the Lender

## Liquidate loan (Lender)

- some time after the Loan expiry and non-payment, the Lender forecloses the Loan
- the Lender forfeits the Principal in lieu of the NFT
- no Admin Fee is paid to the NFTfi contract

## NFTfiAdmin.sol

Administration of

- ERC20 whitelisting - manage tokens that can be used for loans
- ERC721 whitelisting - manage NFT collections that can be used for collateral
- Protocol parameters
  - maximumLoanDuration
  - maximumNumberOfActiveLoans
  - adminFeeInBasisPoints

## NFTfiSigningUtils.sol

Manages verifying ECDSA signatures from off-chain NFTfi orders.
