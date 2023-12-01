// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./NFTfiCollectionOfferSigningUtils.sol";

/**
 * @title  NFTfiCollectionOfferSigningUtilsContract
 * @author NFTfi
 * @notice Helper contract for NFTfi. This contract manages verifying signatures from off-chain NFTfi orders.
 * Based on the version of this same contract used on NFTfi V1
 */
contract NFTfiCollectionOfferSigningUtilsContract {
    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @dev This function overload the previous function to allow the caller to specify the address of the contract
     *
     */
    function isValidLenderSignatureWithIdRange(
        LoanData.Offer memory _offer,
        LoanData.CollectionIdRange memory _idRange,
        LoanData.Signature memory _signature,
        address _loanContract
    ) public view returns (bool) {
        return
            NFTfiCollectionOfferSigningUtils.isValidLenderSignatureWithIdRange(
                _offer,
                _idRange,
                _signature,
                _loanContract
            );
    }
}
