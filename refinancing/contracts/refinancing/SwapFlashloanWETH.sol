// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapFlashloanWETH {
    // solhint-disable-next-line immutable-vars-naming
    address public immutable swapRouterAddress;
    // solhint-disable-next-line immutable-vars-naming
    address public immutable quoterAddress;
    // solhint-disable-next-line immutable-vars-naming
    address public immutable wethAddress;

    /**
     * @dev stores the fee rates for tokens supported by this contract.
     * The keys are token addresses, and the values are the associated fee rates.
     */
    mapping(address => uint24) public supportedTokenFeeRates;

    error tokensFeeRatesArityMismatch();

    /**
     * @dev A struct to hold constructor parameters for the SwapFlashloanWETH contract.
     * (there were too many parameters in the Refinancing constructor)
     *
     * @param swapRouterAddress The address of the Uniswap V3 swap router.
     * @param quoterAddress The address of the Uniswap V3 quoter to estimate trade amounts.
     * @param wethAddress The address of the WETH token contract.
     * @param supportedTokens An array of token addresses that are supported for swaps.
     * @param swapFeeRates An array of fee rates corresponding to the supported tokens.
     */
    struct SwapConstructorParams {
        address swapRouterAddress;
        address quoterAddress;
        address wethAddress;
        address[] supportedTokens;
        uint24[] swapFeeRates;
    }

    /**
     * @dev Creates an instance of the SwapFlashloanWETH contract.
     *
     * @param _params A `SwapConstructorParams` struct containing:
     *                - swapRouterAddress: The address of the Uniswap V3 swap router.
     *                - quoterAddress: The address of the Uniswap V3 quoter for trade estimations.
     *                - wethAddress: The address of the WETH token contract.
     *                - supportedTokens: An array of supported token addresses for swapping.
     *                - swapFeeRates: An array of fee rates corresponding to each supported token.
     *
     * Requirements:
     *
     * - Each supported token address in `_params.supportedTokens` must have a corresponding
     *   fee rate in `_params.swapFeeRates`.
     */
    constructor(SwapConstructorParams memory _params) {
        swapRouterAddress = _params.swapRouterAddress;
        quoterAddress = _params.quoterAddress;
        wethAddress = _params.wethAddress;
        _setSupportedTokenFeeRates(_params.supportedTokens, _params.swapFeeRates);
    }

    /**
     * @dev Sets the fee rates for supported tokens in a single transaction.
     *
     * @param _supportedTokens An array of supported token addresses.
     * @param _swapFeeRates An array of corresponding swap fee rates.
     *
     * Requirements:
     *
     * - The length of the `_supportedTokens` array must be equal to the length of the `_swapFeeRates` array.
     */
    function _setSupportedTokenFeeRates(address[] memory _supportedTokens, uint24[] memory _swapFeeRates) internal {
        if (_supportedTokens.length != _swapFeeRates.length) revert tokensFeeRatesArityMismatch();

        for (uint256 i; i < _supportedTokens.length; ++i) {
            _setSupportedTokenFeeRate(_supportedTokens[i], _swapFeeRates[i]);
        }
    }

    /**
     * @dev Sets the fee rate for a single supported token.
     *
     * @param _supportedToken The address of the supported token.
     * @param _swapFeeRate The swap fee rate for the token.
     */
    function _setSupportedTokenFeeRate(address _supportedToken, uint24 _swapFeeRate) internal {
        supportedTokenFeeRates[_supportedToken] = _swapFeeRate;
    }

    /**
     * @dev Retrieves the swap fee rate for a given token.
     *
     * @param _token The address of the token to query the fee rate for.
     * @return uint24 The fee rate for swaps involving the specified token.
     */
    function getSwapFeeRate(address _token) public view returns (uint24) {
        return supportedTokenFeeRates[_token];
    }

    /**
     * @dev Estimates the amount of WETH needed to receive a specific amount of a given token.
     *
     * @param _tokenOut The address of the token to receive.
     * @param _amountOut The desired amount of the token to receive.
     * @return uint256 The estimated amount of WETH required.
     */
    function getWethAmountNeeded(address _tokenOut, uint256 _amountOut) public returns (uint256) {
        return
            IQuoter(quoterAddress).quoteExactOutputSingle(
                wethAddress,
                _tokenOut,
                getSwapFeeRate(_tokenOut),
                _amountOut,
                uint160(0) // sqrtPriceLimitX96
            );
    }

    /**
     * @dev Estimates the amount of a token needed to receive a specific amount of WETH.
     *
     * @param _tokenIn The address of the token to provide.
     * @param _amountOut The desired amount of WETH to receive.
     * @return uint256 The estimated amount of the input token required.
     */
    function getTokenAmountNeeded(address _tokenIn, uint256 _amountOut) public returns (uint256) {
        return
            IQuoter(quoterAddress).quoteExactOutputSingle(
                _tokenIn,
                wethAddress,
                getSwapFeeRate(_tokenIn),
                _amountOut,
                uint160(0) // sqrtPriceLimitX96
            );
    }

    /**
     * @dev Internal function to swap a token for WETH (Wrapped Ether) using the Uniswap V3 router.
     *
     * This function will attempt to swap the entirety of this contract's balance of the input token
     * for the specified amount of WETH, at the fee rate applicable to the input token. If the swap
     * cannot be completed, it will revert.
     *
     * @param _tokenIn The address of the token to be swapped for WETH.
     * @param _amountOutWeth The desired amount of WETH to receive from the swap.
     *
     * Requirements:
     *
     * - The contract must have a balance of at least `_amountOutWeth` of the token at `_tokenIn`.
     * - The contract must have approval to spend the input token on the Uniswap V3 router.
     */
    function _swapToWeth(address _tokenIn, uint256 _amountOutWeth) internal {
        uint256 balance = IERC20(_tokenIn).balanceOf(address(this));
        IERC20(_tokenIn).approve(swapRouterAddress, balance);

        ISwapRouter(swapRouterAddress).exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: wethAddress,
                fee: getSwapFeeRate(_tokenIn),
                recipient: address(this),
                deadline: block.timestamp + 15, // TODO double check
                amountOut: _amountOutWeth,
                amountInMaximum: balance,
                sqrtPriceLimitX96: uint160(0)
            })
        );
    }

    /**
     * @dev Internal function to swap WETH (Wrapped Ether) for another token using the Uniswap V3 router.
     *
     * This function will attempt to swap the entirety of this contract's balance of WETH
     * for the specified amount of the output token, at the fee rate applicable to the output token.
     * If the swap cannot be completed, it will revert.
     *
     * @param _tokenOut The address of the token to receive from the swap.
     * @param _amountOutToken The desired amount of the output token to receive from the swap.
     *
     * Requirements:
     *
     * - The contract must have a balance of at least `_amountOutToken` worth of WETH.
     * - The contract must have approval to spend WETH on the Uniswap V3 router.
     */
    function _swapFromWeth(address _tokenOut, uint256 _amountOutToken) internal {
        uint256 balance = IERC20(wethAddress).balanceOf(address(this));
        IERC20(wethAddress).approve(swapRouterAddress, balance);

        ISwapRouter(swapRouterAddress).exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: wethAddress,
                tokenOut: _tokenOut,
                fee: getSwapFeeRate(_tokenOut),
                recipient: address(this),
                deadline: block.timestamp + 15, // TODO double check
                amountOut: _amountOutToken,
                amountInMaximum: balance,
                sqrtPriceLimitX96: uint160(0)
            })
        );
    }
}
