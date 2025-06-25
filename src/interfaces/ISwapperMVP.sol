// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ISwapperMVP
 * @notice Interface for the SwapperMVP contract defining events and errors
 * @dev This interface contains all custom errors and events used by SwapperMVP
 */
interface ISwapperMVP {

    //* EVENTS *//

    /**
     * @notice Emitted when a user deposits tokens into the pool
     * @param user The address of the depositor
     * @param amount The amount of fromToken deposited
     */
    event TokensProvided(address indexed user, uint256 indexed amount);

    /**
     * @notice Emitted when the collective swap is executed
     * @param totalFromAmount The total amount of fromToken swapped
     * @param totalToAmount The total amount of toToken received
     */
    event SwapExecuted(uint256 indexed totalFromAmount, uint256 indexed totalToAmount);

    /**
     * @notice Emitted when a user withdraws their tokens
     * @param user The address of the withdrawer
     * @param amount The amount of tokens withdrawn
     * @param isFromToken Whether the withdrawn tokens are fromToken (true) or toToken (false)
     */
    event TokensWithdrawn(address indexed user, uint256 indexed amount, bool isFromToken);

    //* ERRORS *//
    
    /// @notice Thrown when attempting to deposit after swap has occurred
    error SwapperMVP__InvalidState();

    /// @notice Thrown when amount is zero
    /// @param amount The invalid amount provided
    error SwapperMVP__InvalidAmount(uint256 amount);

    /// @notice Thrown when token transfer fails
    /// @param from The sender address
    /// @param to The recipient address  
    /// @param amount The amount that failed to transfer
    error SwapperMVP__TransferFailed(address from, address to, uint256 amount);

}