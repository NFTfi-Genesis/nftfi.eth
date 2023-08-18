// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../utils/NftReceiver.sol";

interface ILoan {
    function liquidateOverdueLoan(uint32 _loanId) external;
}

/**
 * @title  TestSignerContract
 * @author NFTfi
 * @notice Test implementation of a signing contract
 */
contract TestSignerContract is NftReceiver {
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes4) {
        // Validate signatures
        if (ECDSA.recover(_hash, _signature) == admin) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }

    function approveNFT(
        address _token,
        address _to,
        uint256 _tokenId
    ) external {
        IERC721(_token).approve(_to, _tokenId);
    }

    function approveERC20(
        address _token,
        address _to,
        uint256 _amount
    ) external {
        IERC20(_token).approve(_to, _amount);
    }

    function liquidateOverdueLoan(address _loanContract, uint32 _loanId) external {
        ILoan(_loanContract).liquidateOverdueLoan(_loanId);
    }
}
