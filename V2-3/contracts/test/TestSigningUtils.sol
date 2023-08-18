// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "../loans/direct/loanTypes/LoanData.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../utils/NFTfiSigningUtils.sol";

/**
 * @title  TestSigningUtils
 * @author NFTfi
 * @notice Wrapping the NFTfiSigningUtils library in a contract so it can be unit tested
 */
contract TestSigningUtils {
    function getChainID() public view returns (uint256) {
        return NFTfiSigningUtils.getChainID();
    }

    function isValidLenderSignature(LoanData.Offer memory _offer, LoanData.Signature memory _signature)
        public
        view
        returns (bool)
    {
        return NFTfiSigningUtils.isValidLenderSignature(_offer, _signature);
    }

    function isValidLenderRenegotiationSignature(
        uint32 _loanId,
        uint32 _newLoanDuration,
        uint256 _newMaximumRepaymentAmount,
        uint256 _renegotiationFee,
        LoanData.Signature memory _signature
    ) public view returns (bool) {
        return
            NFTfiSigningUtils.isValidLenderRenegotiationSignature(
                _loanId,
                _newLoanDuration,
                _newMaximumRepaymentAmount,
                _renegotiationFee,
                _signature
            );
    }
}
