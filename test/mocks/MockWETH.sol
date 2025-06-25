// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockWETH
 * @notice Mock WETH token for testing purposes
 * @dev Includes WETH-specific deposit/withdraw functionality
 */
contract MockWETH is ERC20 {
    
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    error InsufficientBalance();

    constructor() ERC20("Mock Wrapped Ether", "mWETH") {}

    receive() external payable {
        deposit();
    }

    /**
     * @notice Allows minting for test purposes
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Deposit ETH to receive WETH
     */
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw WETH to receive ETH
     * @param wad Amount to withdraw
     */
    function withdraw(uint256 wad) public {
        if (balanceOf(msg.sender) < wad) revert InsufficientBalance();
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}