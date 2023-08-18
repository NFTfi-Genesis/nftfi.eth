// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "../refinancing/flashloan/ISoloMargin.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockDyDxFlashloan
 * @author NFTfi
 * @dev This contract is a mock of the dYdX flash loan system for testing purposes.
 * It implements the ISoloMargin interface to mimic the behavior of dYdX flash loans on a local network.
 */
contract MockDyDxFlashloan is ISoloMargin {
    // The address of the ERC20 token that will be used for mock flash loans.
    address public erc20;

    /**
     * @dev Contract constructor that sets the ERC20 token address.
     * @param _erc20 The address of the ERC20 token.
     */
    constructor(address _erc20) {
        erc20 = _erc20;
    }

    /**
     * @dev Updates the ERC20 token address.
     * @param _erc20 The new address of the ERC20 token.
     */
    function setErc20(address _erc20) public {
        erc20 = _erc20;
    }

    /**
     * @dev Mocks a flash loan operation. It transfers the loan amount to the borrower,
     * calls the function on the borrower's contract, and then transfers the repayment from the borrower.
     * @param accountInfo Information about the account.
     * @param actions Actions to be performed during the flash loan operation.
     */
    function operate(IFlashloan.AccountInfo[] memory accountInfo, IFlashloan.ActionArgs[] memory actions)
        external
        override
    {
        IERC20(erc20).transfer(msg.sender, actions[0].amount.value);
        IFlashloan(msg.sender).callFunction(msg.sender, accountInfo[0], actions[1].data);
        IERC20(erc20).transferFrom(msg.sender, address(this), actions[2].amount.value);
    }

    /**
     * @dev Returns the address of the ERC20 token. This mocks the function in the real dYdX contract which
     * returns the address of the token for a given market id.
     * @param *_marketId The id of the market (not used in this mock contract).
     * @return The address of the ERC20 token.
     */
    function getMarketTokenAddress(uint256) external view override returns (address) {
        return erc20;
    }
}
