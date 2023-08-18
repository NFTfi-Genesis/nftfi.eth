// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/INftfiHub.sol";
import "../interfaces/IPermittedAirdrops.sol";
import "../interfaces/INftWrapper.sol";
import "../utils/ContractKeys.sol";

/**
 * @title AirdropFlashLoan
 * @author NFTfi
 * @dev
 */
contract AirdropFlashLoan is ERC721Holder, ERC1155Holder, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    INftfiHub public immutable hub;

    constructor(address _nftfiHub) {
        hub = INftfiHub(_nftfiHub);
    }

    function pullAirdrop(
        address _nftCollateralContract,
        uint256 _nftCollateralId,
        address _nftWrapper,
        address _target,
        bytes calldata _data,
        address _nftAirdrop,
        uint256 _nftAirdropId,
        bool _is1155,
        uint256 _nftAirdropAmount,
        address _beneficiary
    ) external nonReentrant {
        require(
            IPermittedAirdrops(hub.getContract(ContractKeys.PERMITTED_AIRDROPS)).isValidAirdrop(
                abi.encode(_target, _getSelector(_data))
            ),
            "Invalid Airdrop"
        );

        // assumes that the collateral nft has been transferreded to this contract before calling this function
        _target.functionCall(_data);

        // return the collateral
        _transferNFT(_nftWrapper, address(this), msg.sender, _nftCollateralContract, _nftCollateralId);

        // in case that arbitray function from _target does not send the airdrop to a specified address
        if (_nftAirdrop != address(0) && _beneficiary != address(0)) {
            // send the airdrop to the beneficiary
            if (_is1155) {
                IERC1155(_nftAirdrop).safeTransferFrom(
                    address(this),
                    _beneficiary,
                    _nftAirdropId,
                    _nftAirdropAmount,
                    "0x"
                );
            } else {
                IERC721(_nftAirdrop).safeTransferFrom(address(this), _beneficiary, _nftAirdropId);
            }
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC1155Receiver) returns (bool) {
        return _interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(_interfaceId);
    }

    function _transferNFT(
        address _nftWrapper,
        address _sender,
        address _recipient,
        address _nftCollateralContract,
        uint256 _nftCollateralId
    ) internal {
        _nftWrapper.functionDelegateCall(
            abi.encodeWithSelector(
                INftWrapper(_nftWrapper).transferNFT.selector,
                _sender,
                _recipient,
                _nftCollateralContract,
                _nftCollateralId
            ),
            "NFT was not successfully transferred"
        );
    }

    function _getSelector(bytes memory _data) internal pure returns (bytes4 selector) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(_data, 32))
        }
    }
}
