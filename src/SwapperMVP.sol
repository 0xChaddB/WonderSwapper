// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapperMVP} from "src/interfaces/ISwapperMVP.sol";

/**
   * @title SwapperMVP
   * @notice A contract that pools user deposits, swaps them collectively, and allows proportional withdrawals
   * @dev This MVP implementation supports a single one-way swap cycle only. For production use with multiple cycles,
   *      consider implementing a round-based system. The contract assumes a 1:1 exchange ratio between tokens.
   *      If the deposited toToken amount is superior to totalDeposited when swapping, excess tokens will be locked in the contract.
   * @author Chaddb
*/
contract SwapperMVP is ISwapperMVP {

    //* STATE VARIABLE *//

    /// @notice Tracks the amount of fromToken deposited by each user
    mapping(address user => uint256 amount) public deposits;

    /// @notice Indicates whether the collective swap has been executed
    bool public hasSwapped;

    /// @notice Total amount of fromToken deposited across all users
    uint256 public totalDeposited;

    /// @notice The token that users deposit (immutable after deployment)
    address public immutable fromToken;
    
    /// @notice The token that users receive after swap (immutable after deployment)
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
        require(!hasSwapped, SwapperMVP__InvalidState());
        require(_amount > 0, SwapperMVP__InvalidAmount(_amount));
        // The ERC20, should check for user balance and allowance 
        IERC20(fromToken).transferFrom(msg.sender, address(this), _amount);

        deposits[msg.sender] += _amount;
        totalDeposited += _amount;
        emit TokensProvided(msg.sender, _amount);
    }

    /**
     * @notice Executes the collective swap for all deposited tokens
     * @dev Can only be called once when there are deposits and sufficient toToken liquidity.
     *      Requires the governor to have pre-funded the contract with toToken when deployed.
     *      Anyone can call this function to trigger the swap.
     */
    function swap() external {
      require(!hasSwapped, SwapperMVP__InvalidState());
      require(totalDeposited > 0, SwapperMVP__NoTokensToSwap());

      // Governor (deployer) will need to provide toToken liquidity
      uint256 toBalance = IERC20(toToken).balanceOf(address(this));
      require(toBalance >= totalDeposited, SwapperMVP_NotEnoughLiquidity(toBalance, totalDeposited));

      hasSwapped = true;
      emit SwapExecuted(totalDeposited, totalDeposited); // 1:1
    }

    /**
     * @notice Allows users to withdraw their proportional share of toToken after swap
     * @dev Can only be called after the swap has been executed.
     *      Users receive the same amount of toToken as fromToken deposited (1:1 ratio).
     *      Each user can only withdraw once.
     */
    function withdraw() external {
        require(hasSwapped, SwapperMVP__InvalidState());
        uint256 amount = deposits[msg.sender];
        require(amount > 0, SwapperMVP_NoTokenToWithdraw());

        deposits[msg.sender] = 0;
        IERC20(address(toToken)).transfer(msg.sender, amount);

        emit TokensWithdrawn(msg.sender, amount);
    }
    
}