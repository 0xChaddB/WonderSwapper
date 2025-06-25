// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapperMVP {

    //* STATE VARIABLE *//

    mapping(address user => uint256 amount) public deposits;

    bool public hasSwapped;

    address public immutable fromToken;
    address public immutable toToken;

    //* EVENT *//
    event TokensProvided(address indexed user, uint256 indexed amount);

    //* ERRORS *//
    error SwapperMVP__InvalidState(); // ?
    error SwapperMVP__InvalidAmount(uint256 amount);
    error SwapperMVP__AllowanceNeeded(address user, uint256 amount);
    error SwapperMVP__TransferFailed(address from, address to, uint256 amount);

    //* CONSTRUCTOR *//
    
    constructor(address _fromToken, address _toToken) {
        fromToken = _fromToken;
        toToken = _toToken;
    }


    //* FUNCTIONS *//

    function provide(uint256 _amount) external {
        
        // Logic : verify state of the swapper?, verify amount, Approval of fromToken for amount specified, transferFrom msg.sender to this contract.
        require(!hasSwapped, SwapperMVP__InvalidState()); // ?
        require(_amount > 0, SwapperMVP__InvalidAmount(_amount));

        // User need to approve before calling this function!
        require(IERC20(fromToken).allowance(msg.sender, address(this)) >= _amount, SwapperMVP__AllowanceNeeded(msg.sender, _amount));
        
        bool success = IERC20(fromToken).transferFrom(msg.sender, address(this), _amount);
        require(success, SwapperMVP__TransferFailed(msg.sender, address(this), _amount));

        deposits[msg.sender] += _amount;

        emit TokensProvided(msg.sender, _amount);
    }


}