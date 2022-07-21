// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/ContractKeys.sol";
import "../interfaces/IPermittedERC20s.sol";
import "../interfaces/INftfiHub.sol";
import "../interfaces/IDirectLoanCoordinator.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TokenTrade {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    INftfiHub public hub;

    bytes32 public immutable LOAN_COORDINATOR;

    constructor(address _nftfiHub, bytes32 _loanCoordinatorKey) {
        hub = INftfiHub(_nftfiHub);
        LOAN_COORDINATOR = _loanCoordinatorKey;
    }

    /**
     * @notice A mapping that takes both a user's address and a trade nonce that was first used when signing an
     * off-chain order and checks whether that nonce has previously either been used for a trade, or has been
     * pre-emptively cancelled. The nonce referred to here is not the same as an Ethereum account's nonce.
     * We are referring instead to nonces that are used by both the lender and the borrower when they are first
     * signing off-chain NFTfi orders.
     *
     * These nonces can be any uint256 value that the user has not previously used to sign an off-chain order. Each
     * nonce can be used at most once per user within NFTfi, regardless of whether they are the lender or the borrower
     * in that situation. This serves two purposes. First, it prevents replay attacks where an attacker would submit a
     * user's off-chain order more than once. Second, it allows a user to cancel an off-chain order by calling
     * NFTfi.cancelTradeCommitment(), which marks the nonce as used and prevents any future trade from
     * using the user's off-chain order that contains that nonce.
     */
    mapping(address => mapping(uint256 => bool)) private _nonceHasBeenUsedForUser;

    /**
     * @notice This function can be called by the initiator to cancel all off-chain orders that they
     * have signed that contain this nonce. If the off-chain orders were created correctly, there should only be one
     * off-chain order that contains this nonce at all.
     *
     * The nonce referred to here is not the same as an Ethereum account's nonce. We are referring
     * instead to nonces that are used by both the lender and the borrower when they are first signing off-chain NFTfi
     * orders. These nonces can be any uint256 value that the user has not previously used to sign an off-chain order.
     * Each nonce can be used at most once per user within NFTfi, regardless of whether they are the lender or the
     * borrower in that situation. This serves two purposes. First, it prevents replay attacks where an attacker would
     * submit a user's off-chain order more than once. Second, it allows a user to cancel an off-chain order by calling
     * NFTfi.cancelTradeCommitment(), which marks the nonce as used and prevents any future trade from
     * using the user's off-chain order that contains that nonce.
     *
     * @param  _nonce - User nonce
     */
    function cancelTradeCommitment(uint256 _nonce) external {
        require(!_nonceHasBeenUsedForUser[msg.sender][_nonce], "Invalid nonce");
        _nonceHasBeenUsedForUser[msg.sender][_nonce] = true;
    }

    /**
     * @notice This function can be used to view whether a particular nonce for a particular user has already been used,
     * either from a successful trade or a cancelled off-chain order.
     *
     * @param _user - The address of the user. This function works for both lenders and borrowers alike.
     * @param  _nonce - The nonce referred to here is not the same as an Ethereum account's nonce. We are referring
     * instead to nonces that are used by both the lender and the borrower when they are first signing off-chain
     * NFTfi orders. These nonces can be any uint256 value that the user has not previously used to sign an off-chain
     * order. Each nonce can be used at most once per user within NFTfi, regardless of whether they are the lender or
     * the borrower in that situation. This serves two purposes:
     * - First, it prevents replay attacks where an attacker would submit a user's off-chain order more than once.
     * - Second, it allows a user to cancel an off-chain order by calling NFTfi.cancelTradeCommitment()
     * , which marks the nonce as used and prevents any future trade from using the user's off-chain order that contains
     * that nonce.
     *
     * @return A bool representing whether or not this nonce has been used for this user.
     */
    function getNonceUsage(address _user, uint256 _nonce) external view returns (bool) {
        return _nonceHasBeenUsedForUser[_user][_nonce];
    }

    /**
     * @notice trade initiator sells their obligation receipt to the accepter
     * Activates an off chain proposed ERC20-loanNFT token trade, works very much like the loan offer acceptal
     * both parties have to approve the token allowances for the trade contract before calling this function
     *
     * parameters: see trade()
     */
    function sellObligationReceipt(
        address _tradeERC20,
        uint256 _nftId,
        uint256 _erc20Amount,
        address _buyer,
        uint256 _buyerNonce,
        uint256 _expiry,
        bytes memory _buyerSignature
    ) external {
        require(!_nonceHasBeenUsedForUser[_buyer][_buyerNonce], "Buyer nonce invalid");
        _nonceHasBeenUsedForUser[_buyer][_buyerNonce] = true;
        IDirectLoanCoordinator loanCoordinator = IDirectLoanCoordinator(hub.getContract(LOAN_COORDINATOR));
        address obligationReceipt = loanCoordinator.obligationReceiptToken();
        require(
            isValidTradeSignature(
                _tradeERC20,
                obligationReceipt,
                _nftId,
                _erc20Amount,
                _buyer,
                _buyerNonce,
                _expiry,
                _buyerSignature
            ),
            "Trade signature is invalid"
        );
        trade(_tradeERC20, obligationReceipt, _nftId, _erc20Amount, msg.sender, _buyer);
    }

    /**
     * @notice trade initiator buys obligation receipt of the accepter
     * Activates an off chain proposed ERC20-loanNFT token trade, works very much like the loan offer acceptal
     * both parties have to approve the token allowances for the trade contract before calling this function
     *
     * parameters: see trade()
     */
    function buyObligationReceipt(
        address _tradeERC20,
        uint256 _nftId,
        uint256 _erc20Amount,
        address _seller,
        uint256 _sellerNonce,
        uint256 _expiry,
        bytes memory _sellerSignature
    ) external {
        require(!_nonceHasBeenUsedForUser[_seller][_sellerNonce], "Seller nonce invalid");
        _nonceHasBeenUsedForUser[_seller][_sellerNonce] = true;
        IDirectLoanCoordinator loanCoordinator = IDirectLoanCoordinator(hub.getContract(LOAN_COORDINATOR));
        address obligationReceipt = loanCoordinator.obligationReceiptToken();
        require(
            isValidTradeSignature(
                _tradeERC20,
                obligationReceipt,
                _nftId,
                _erc20Amount,
                _seller,
                _sellerNonce,
                _expiry,
                _sellerSignature
            ),
            "Trade signature is invalid"
        );
        trade(_tradeERC20, obligationReceipt, _nftId, _erc20Amount, _seller, msg.sender);
    }

    /**
     * @notice trade initiator sells their promissory note to the accepter
     * Activates an off chain proposed ERC20-loanNFT token trade, works very much like the loan offer acceptal
     * both parties have to approve the token allowances for the trade contract before calling this function
     *
     * parameters: see trade()
     */
    function sellPromissoryNote(
        address _tradeERC20,
        uint256 _nftId,
        uint256 _erc20Amount,
        address _buyer,
        uint256 _buyerNonce,
        uint256 _expiry,
        bytes memory _buyerSignature
    ) external {
        require(!_nonceHasBeenUsedForUser[_buyer][_buyerNonce], "Buyer nonce invalid");
        _nonceHasBeenUsedForUser[_buyer][_buyerNonce] = true;
        IDirectLoanCoordinator loanCoordinator = IDirectLoanCoordinator(hub.getContract(LOAN_COORDINATOR));
        address promissoryNote = loanCoordinator.promissoryNoteToken();
        require(
            isValidTradeSignature(
                _tradeERC20,
                promissoryNote,
                _nftId,
                _erc20Amount,
                _buyer,
                _buyerNonce,
                _expiry,
                _buyerSignature
            ),
            "Trade signature is invalid"
        );
        trade(_tradeERC20, promissoryNote, _nftId, _erc20Amount, msg.sender, _buyer);
    }

    /**
     * @notice trade initiator buys promissory note of the accepter
     * Activates an off chain proposed ERC20-loanNFT token trade, works very much like the loan offer acceptal
     * both parties have to approve the token allowances for the trade contract before calling this function
     *
     * parameters: see trade()
     */
    function buyPromissoryNote(
        address _tradeERC20,
        uint256 _nftId,
        uint256 _erc20Amount,
        address _seller,
        uint256 _sellerNonce,
        uint256 _expiry,
        bytes memory _sellerSignature
    ) external {
        require(!_nonceHasBeenUsedForUser[_seller][_sellerNonce], "Seller nonce invalid");
        _nonceHasBeenUsedForUser[_seller][_sellerNonce] = true;
        IDirectLoanCoordinator loanCoordinator = IDirectLoanCoordinator(hub.getContract(LOAN_COORDINATOR));
        address promissoryNote = loanCoordinator.promissoryNoteToken();
        require(
            isValidTradeSignature(
                _tradeERC20,
                promissoryNote,
                _nftId,
                _erc20Amount,
                _seller,
                _sellerNonce,
                _expiry,
                _sellerSignature
            ),
            "Trade signature is invalid"
        );
        trade(_tradeERC20, promissoryNote, _nftId, _erc20Amount, _seller, msg.sender);
    }

    /**
     * @notice Activates an off chain proposed ERC20-loanNFT token trade, works very much like the loan offer acceptal
     * both parties have to approve the token allowances for the trade contract before calling this function
     *
     * @param _tradeERC20 - Contract address for the token denomination of the erc20 side of the trade,
     * can only be a premitted erc20 token
     * @param _tradeNft - Contract address for the loanNFT side of the trade,
     * can only be the 'promissory note' or the 'obligation receipt' of the used loan coordinator
     * @param _nftId - ID of the loanNFT to be tradeped
     * true:
     *      initiator sells loanNFT for erc20, accepter buys loanNFT for erc20
     * false:
     *      initiator buys loanNFT for erc20, accepter sells loanNFT for erc20
     * @param _erc20Amount - amount of payment price in erc20 for the loanNFT
     * @param _seller - address of the user selling the loanNFT for ERC20 tokens
     * @param _buyer - address of the user buying the loanNFT for ERC20 tokens
     */
    function trade(
        address _tradeERC20,
        address _tradeNft,
        uint256 _nftId,
        uint256 _erc20Amount,
        address _seller,
        address _buyer
    ) internal {
        require(
            IPermittedERC20s(hub.getContract(ContractKeys.PERMITTED_ERC20S)).getERC20Permit(_tradeERC20),
            "Currency denomination is not permitted"
        );
        IERC20(_tradeERC20).safeTransferFrom(_buyer, _seller, _erc20Amount);
        IERC721(_tradeNft).safeTransferFrom(_seller, _buyer, _nftId);
    }

    /**
     * @notice This function is called in trade()to validate the trade initiator's signature that the lender
     * has provided off-chain to verify that they did indeed want to
     * agree to this loan renegotiation according to these terms.
     *
     * @param _tradeERC20 - Contract address for the token denomination of the erc20 side of the trade,
     * can only be a premitted erc20 token
     * @param _tradeNft - Contract address for the loanNFT side of the trade,
     * can only be the 'promissory note' or the 'obligation receipt' of the used loan coordinator
     * @param _nftId - ID of the loanNFT to be tradeped
     * @param _erc20Amount - amount of payment price in erc20 for the loanNFT
     * @param _accepter - address of the user accepting the proposed trade, they have created the off-chain signature
     * @param _accepterNonce - The nonce referred to here is not the same as an Ethereum account's nonce. We are
     * referring instead to nonces that are used by both the lender and the borrower when they are first signing
     * off-chain NFTfi orders. These nonces can be any uint256 value that the user has not previously used to sign an
     * off-chain order. Each nonce can be used at most once per user within NFTfi, regardless of whether they are the
     * lender or the borrower in that situation. This serves two purposes:
     * - First, it prevents replay attacks where an attacker would submit a user's off-chain order more than once.
     * - Second, it allows a user to cancel an off-chain order by calling NFTfi.cancelTradeCommitment()
     * , which marks the nonce as used and prevents any future trade from using the user's off-chain order that contains
     * that nonce.
     * @param _expiry - The date when the trade offer expires
     * @param _accepterSignature - The ECDSA signature of the trade initiator,
     * obtained off-chain ahead of time, signing the
     * following combination of parameters:
     * - tradeERC20,
     * - tradeLoanNft,
     * - loanNftId,
     * - erc20Amount,
     * - initiator,
     * - accepter,
     * - initiatorNonce,
     * - expiry,
     * - chainId
     */
    function isValidTradeSignature(
        address _tradeERC20,
        address _tradeNft,
        uint256 _nftId,
        uint256 _erc20Amount,
        address _accepter,
        uint256 _accepterNonce,
        uint256 _expiry,
        bytes memory _accepterSignature
    ) public view returns (bool) {
        require(block.timestamp <= _expiry, "Trade Signature has expired");
        if (_accepter == address(0)) {
            return false;
        } else {
            bytes32 message = keccak256(
                abi.encodePacked(
                    _tradeERC20,
                    _tradeNft,
                    _nftId,
                    _erc20Amount,
                    _accepter,
                    _accepterNonce,
                    _expiry,
                    getChainID()
                )
            );

            bytes32 messageWithEthSignPrefix = message.toEthSignedMessageHash();

            return (messageWithEthSignPrefix.recover(_accepterSignature) == _accepter);
        }
    }

    /**
     * @dev This function gets the current chain ID.
     */
    function getChainID() internal view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }
}
