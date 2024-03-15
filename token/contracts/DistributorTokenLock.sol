// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./DistributorRegistry.sol";
import "./TokenUtilityAccounting.sol";
import "./BaseTokenLock.sol";

import "./utils/ProtocolSigningUtils.sol";

/**
 * @title DistributorTokenLock
 * @author NFTfi
 * @dev This contract allows users to lock tokens with a request-based withdrawal mechanism. Withdrawals
 * have cooldown periods and need a protocol signature if the tokens withdrawn come from the distributor
 * and not from an external source. It integrates with a `TokenUtilityAccounting` contract.
 */
contract DistributorTokenLock is BaseTokenLock {
    DistributorRegistry public immutable distributorRegistry;

    address public protocolSignerAddress;

    /**
     * @dev Initializes the contract, setting initial admin, token, distributor, and cooldown values.
     * @param _admin Admin's address.
     * @param _nftfi Address of the NFTFI token.
     * @param _distributorRegistry MerkleDistributor contract address.
     * @param _protocolSignerAddress protocol signature checking feature can be turned off by setting it to 0 address
     * @param _cooldown Cooldown time in seconds.
     */
    constructor(
        address _admin,
        address _nftfi,
        address _distributorRegistry,
        address _tokenUtilityAccounting,
        address _protocolSignerAddress,
        uint256 _cooldown
    ) BaseTokenLock(_admin, _nftfi, _tokenUtilityAccounting, _cooldown) {
        distributorRegistry = DistributorRegistry(_distributorRegistry);
        protocolSignerAddress = _protocolSignerAddress;
    }

    /**
     * @dev Allows the distributor to lock tokens on behalf of a beneficiary (claimer).
     * Only callable by the distributor, requests a withdrawal for the user for the
     * full amount automatically, so cooldown starts at claim time.
     * User gets no "utility points" (TokenUtilityAccounting) except if they delete the created request.
     * @param _amount Amount of tokens to lock.
     * @param _beneficiary Address of the beneficiary.
     */
    function lockTokens(uint256 _amount, address _beneficiary) external {
        require(distributorRegistry.isDistributor(msg.sender), "Only registered distributor");
        _lockTokens(_amount, _beneficiary);
        _requestWithdrawal(_amount, _beneficiary);
    }

    /**
     * @dev Allows a user to withdraw their tokens after a cooldown,
     * with a protocol signature if we withdraw from the ditributor locked pot.
     * @param _amount Amount of tokens to withdraw.
     * @param _requestTimestamp Timestamp of the original withdrawal request.
     * @param _protocolSignatureExpiry The timestamp after which the signature is considered expired and invalid.
     * Not checked if we withdraw from the non-ditributor locked pot.
     * Can be left with 0 values in that case.
     * @param _protocolSignature The actual ECDSA signature bytes of the signed data
     * Not checked if we withdraw from the non-ditributor locked pot.
     * Can be left with 0 values in that case.
     */
    function withdraw(
        uint256 _amount,
        uint256 _requestTimestamp,
        uint256 _protocolSignatureExpiry,
        bytes calldata _protocolSignature
    ) public {
        if (protocolSignerAddress != address(0)) {
            require(
                ProtocolSigningUtils.isValidProtocolSignature(
                    msg.sender,
                    _amount,
                    _requestTimestamp,
                    ProtocolSigningUtils.ProtocolSignature({
                        expiry: _protocolSignatureExpiry,
                        signer: protocolSignerAddress,
                        signature: _protocolSignature
                    })
                ),
                "Protocol signature invalid"
            );
        }

        _withdraw(_amount, _requestTimestamp);
        tokenUtilityAccounting.unlock(msg.sender, _amount);
    }

    function withdrawMultiple(
        uint256[] calldata _amounts,
        uint256[] calldata _requestTimestamps,
        uint256[] calldata _protocolSignatureExpiries,
        bytes[] calldata _protocolSignatures
    ) external {
        require(_amounts.length == _requestTimestamps.length, "parameter arity mismatch");
        require(_amounts.length == _requestTimestamps.length, "parameter arity mismatch 2");
        require(_amounts.length == _requestTimestamps.length, "parameter arity mismatch 3");
        for (uint256 i = 0; i < _amounts.length; ++i) {
            withdraw(_amounts[i], _requestTimestamps[i], _protocolSignatureExpiries[i], _protocolSignatures[i]);
        }
    }

    /**
     * @dev Sets up new protocol signer address,
     * protocol signature checking feature can be turned off by setting it to 0 address
     * @param _protocolSignerAddress -
     */
    function setProtocolSignerAddress(address _protocolSignerAddress) external onlyOwner {
        protocolSignerAddress = _protocolSignerAddress;
    }
}
