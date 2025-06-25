// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapperMVP} from "src/interfaces/ISwapperMVP.sol";

/**
   * @title SwapperMVP
   * @notice A contract that pools user deposits, swaps them collectively, and allows proportional withdrawals
   * @dev This MVP implementation supports a single swap cycle only. For production use with multiple cycles,
   *      consider implementing a round-based system. The contract assumes a 1:1 exchange ratio between tokens.
   * @author Chaddb
*/
contract SwapperMVP is ISwapperMVP {

    //* STATE VARIABLE *//

    mapping(address user => uint256 amount) public deposits;

    bool public hasSwapped;

    uint256 public totalDeposited;

    address public immutable fromToken;
    address public immutable toToken;

    //* CONSTRUCTOR *//
    /**
     * @notice Initializes the swapper with token pair configuration
     * @param _fromToken The token users will deposit (e.g., DAI)
     * @param _toToken The token users will receive after swap (e.g., WETH)
     * @dev Both tokens must be valid ERC20 contracts. Governor must provide toToken liquidity.
    */
    constructor(address _fromToken, address _toToken) {
        fromToken = _fromToken;
        toToken = _toToken;
    }


    //* FUNCTIONS *//

    /**
     * @notice Allows users to deposit fromToken into the pool for collective swapping
     * @param _amount The amount of fromToken to deposit
     * @dev Requires prior approval of this contract to spend user's tokens.
     *      Deposits are only accepted before the swap has been executed.
     *      Multiple deposits from the same user are accumulated.
     * @custom:security Users must call approve() on the fromToken before calling this function
    */
    function provide(uint256 _amount) external {
        IERC20 token = IERC20(fromToken);

        require(!hasSwapped, SwapperMVP__InvalidState()); // ?
        require(_amount > 0, SwapperMVP__InvalidAmount(_amount));
        // if user dont allow the contract to spend the tokens, the error "ERC20: insufficient allowance" should appear
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, SwapperMVP__TransferFailed(msg.sender, address(this), _amount));

        deposits[msg.sender] += _amount;
        totalDeposited += _amount;
        emit TokensProvided(msg.sender, _amount);
    }


}