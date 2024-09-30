// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pool.sol"; // Import the original Pool contract

/**
 * @title PoolV2 Contract
 * @dev This contract extends the Pool contract with additional functionality for fee management.
 */
contract PoolV2 is Pool {
    // New storage variable added to the contract
    uint256 public feeRate;

    // Event to log fee rate updates
    event FeeRateUpdated(uint256 newFeeRate);

    /**
     * @dev Initializes the new contract with the fee rate.
     * @param _feeRate The initial fee rate (e.g., 3 for 0.3%).
     */
    function initializeV2(uint256 _feeRate) external onlyRole(ADMIN_ROLE) {
        feeRate = _feeRate;
    }

    /**
     * @dev Allows admin to update the fee rate.
     * @param _feeRate The new fee rate (e.g., 3 for 0.3%).
     */
    function setFeeRate(uint256 _feeRate) external onlyRole(ADMIN_ROLE) {
        feeRate = _feeRate;
        emit FeeRateUpdated(_feeRate);
    }

    /**
     * @dev Override the swap function to incorporate the fee rate.
     */
    function swap(
        uint256 tokenInId,
        uint256 tokenOutId,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        payable
        override
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "AmountIn must be greater than zero");
        require(tokenInId != tokenOutId, "Tokens must be different");
        require(
            tokenInId < tokens.length && tokenOutId < tokens.length,
            "Unsupported tokens"
        );

        address tokenIn = tokens[tokenInId];
        address tokenOut = tokens[tokenOutId];
        uint256 reserveIn = reserves[tokenIn];
        uint256 reserveOut = reserves[tokenOut];

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        _depositToken(tokenIn, amountIn);
        reserves[tokenIn] = reserveIn + amountIn;

        // Apply custom fee rate (feeRate is stored as basis points, e.g., 30 for 0.3%)
        uint256 amountInWithFee = (amountIn * (1000 - feeRate)) / 1000;

        amountOut =
            (amountInWithFee * reserveOut) /
            (reserveIn + amountInWithFee);
        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut <= reserveOut, "Not enough liquidity");

        reserves[tokenOut] = reserveOut - amountOut;
        _withdrawToken(tokenOut, msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
}
