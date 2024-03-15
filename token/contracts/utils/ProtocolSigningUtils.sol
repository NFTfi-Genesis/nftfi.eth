// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @title  ProtocolSigningUtils
 * @author NFTfi
 * @notice Helper library for NFTfi. This contract manages verifying signatures
 * from an NFTfi protocol address to enforce KYC requirements on-chain
 */
library ProtocolSigningUtils {
    /**
     * @dev Signature struct
     *
     * @param expiry The timestamp after which the signature is considered expired and invalid.
     * @param signer Signing protocol address
     * @param signature The actual ECDSA signature bytes of the signed data
     */
    struct ProtocolSignature {
        uint256 expiry;
        address signer;
        bytes signature;
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice Verifies the validity of a protocol signature.
     * @dev This function checks whether the protocol signature is valid and hasn't expired.
     * It constructs a message from the input parameters and verifies its signature against
     * the expected signer.
     *
     * @param _user The address of the user initiating the withdrawal.
     * @param _amount The amount the user is withdrawing.
     * @param _requestTimestamp The timestamp when the withdrawal request was made.
     * @param _protocolSignature - The signature structure containing:
     * - signer: The address of the signer, in this case and address controlled by the protocol
     * - expiry: Date when the signature expires
     * - signature: The ECDSA signature of the protocol, obtained off-chain ahead of time, signing the following
     * combination of parameters:
     *   - user withdrawing from TokenLock
     *   - amount withdrawn
     *   - requestTimestamp time of the request for the withdrawal to check signature for each individual call
     *   - protocolSignature.signer
     *   - protocolSignature.expiry
     * @return bool True if the protocol signature is valid; otherwise, false.
     */
    function isValidProtocolSignature(
        address _user,
        uint256 _amount,
        uint256 _requestTimestamp,
        ProtocolSignature memory _protocolSignature
    ) internal view returns (bool) {
        require(block.timestamp <= _protocolSignature.expiry, "Protocol Signature expired");

        bytes32 message = keccak256(
            abi.encodePacked(_user, _amount, _requestTimestamp, _protocolSignature.signer, _protocolSignature.expiry)
        );

        return
            SignatureChecker.isValidSignatureNow(
                _protocolSignature.signer,
                ECDSA.toEthSignedMessageHash(message),
                _protocolSignature.signature
            );
    }
}

/**
 * @title  ProtocolSigningUtils
 * @author NFTfi
 * @notice Deployable contract for of the above library
 */
contract ProtocolSigningUtilsContract {
    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice Verifies the validity of a protocol signature.
     * @dev This function checks whether the protocol signature is valid and hasn't expired.
     * It constructs a message from the input parameters and verifies its signature against
     * the expected signer.
     *
     * @param _user The address of the user initiating the withdrawal.
     * @param _amount The amount the user is withdrawing.
     * @param _requestTimestamp The timestamp when the withdrawal request was made.
     * @param _protocolSignature - The signature structure containing:
     * - signer: The address of the signer, in this case and address controlled by the protocol
     * - expiry: Date when the signature expires
     * - signature: The ECDSA signature of the protocol, obtained off-chain ahead of time, signing the following
     * combination of parameters:
     *   - user withdrawing from TokenLock
     *   - amount withdrawn
     *   - requestTimestamp time of the request for the withdrawal to check signature for each individual call
     *   - protocolSignature.signer
     *   - protocolSignature.expiry
     * @return bool True if the protocol signature is valid; otherwise, false.
     */
    function isValidProtocolSignature(
        address _user,
        uint256 _amount,
        uint256 _requestTimestamp,
        ProtocolSigningUtils.ProtocolSignature memory _protocolSignature
    ) external view returns (bool) {
        return ProtocolSigningUtils.isValidProtocolSignature(_user, _amount, _requestTimestamp, _protocolSignature);
    }
}
