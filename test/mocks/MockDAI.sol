// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockDAI
 * @notice Mock DAI token for testing purposes
 * @dev Mints initial supply to deployer
 */
contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") {
        _mint(msg.sender, 1_000_000 * 10**18); // 1M DAI
    }

    /**
     * @notice Allows minting for test purposes
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}