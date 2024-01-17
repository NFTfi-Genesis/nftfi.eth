// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {ISoloMargin, IFlashloan} from "../refinancing/flashloan/ISoloMargin.sol";
import {Ownable} from "../utils/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockDyDxFlashloan
 * @author NFTfi
 * @dev This contract is a mock of the dYdX flash loan system for testing purposes.
 * It implements the ISoloMargin interface to mimic the behavior of dYdX flash loans on a local network.
 */
contract MockDyDxFlashloan is ISoloMargin, Ownable {
    mapping(uint256 => address) public markets;

    /**
     * @dev Contract constructor that sets the ERC20 markets.
     * @param _erc20s The address of the ERC20 tokens
     * @param _marketIds The id of the markets
     */
    constructor(address[] memory _erc20s, uint256[] memory _marketIds, address _admin) Ownable(_admin) {
        _setMarkets(_erc20s, _marketIds);
    }

    /**
     * @dev Updates the ERC20 token address.
     * @param _erc20 The new address of the ERC20 token.
     */
    function setMarket(address _erc20, uint256 _marketId) public onlyOwner {
        _setMarket(_erc20, _marketId);
    }

    function setMarkets(address[] memory _erc20s, uint256[] memory _marketIds) public onlyOwner {
        _setMarkets(_erc20s, _marketIds);
    }

    /**
     * @dev Updates the ERC20 token address.
     * @param _erc20 The new address of the ERC20 token.
     */
    function _setMarket(address _erc20, uint256 _marketId) internal {
        markets[_marketId] = _erc20;
    }

    function _setMarkets(address[] memory _erc20s, uint256[] memory _marketIds) internal {
        // solhint-disable-next-line custom-errors
        require(_erc20s.length == _marketIds.length, "setMarkets function information arity mismatch");
        for (uint256 i; i < _erc20s.length; ++i) {
            _setMarket(_erc20s[i], _marketIds[i]);
        }
    }

    /**
     * @dev Mocks a flash loan operation. It transfers the loan amount to the borrower,
     * calls the function on the borrower's contract, and then transfers the repayment from the borrower.
     * @param accountInfo Information about the account.
     * @param actions Actions to be performed during the flash loan operation.
     */
    function operate(
        IFlashloan.AccountInfo[] memory accountInfo,
        IFlashloan.ActionArgs[] memory actions
    ) external override {
        IERC20(markets[actions[0].primaryMarketId]).transfer(msg.sender, actions[0].amount.value);
        IFlashloan(msg.sender).callFunction(msg.sender, accountInfo[0], actions[1].data);
        IERC20(markets[actions[2].primaryMarketId]).transferFrom(msg.sender, address(this), actions[2].amount.value);
    }

    /**
     * @dev Returns the address of the ERC20 token. This mocks the function in the real dYdX contract which
     * returns the address of the token for a given market id.
     * @param *_marketId The id of the market (not used in this mock contract).
     * @return The address of the ERC20 token.
     */
    function getMarketTokenAddress(uint256 _marketId) external view override returns (address) {
        return markets[_marketId];
    }
}
