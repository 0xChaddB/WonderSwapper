// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SwapperMVP, ISwapperMVP} from "src/SwapperMVP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Fork tests using real mainnet tokens and state
 * @dev Tests the SwapperMVP contract with actual DAI and WETH from mainnet
 */
contract SwapperMVPForkTest is Test {
  // Mainnet addresses
  address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  
  // Whale addresses (holders with large balances)
  address constant DAI_WHALE = 0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf; // Polygon bridge
  address constant WETH_WHALE = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E; // Large holder
  
  SwapperMVP public swapper;
  
  address public user1 = makeAddr("user1");
  address public user2 = makeAddr("user2");
  address public governor = makeAddr("governor");
  
  uint256 constant FORK_BLOCK = 20_000_000; // June 2024 block
  uint256 constant INITIAL_BALANCE = 10_000e18;
  uint256 constant DEPOSIT_AMOUNT = 1_000e18;
  
  function setUp() public {
    // Fork mainnet at specific block
    vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
    
    // Deploy SwapperMVP
    swapper = new SwapperMVP(DAI, WETH);
    
    // Fund users with DAI from whale
    vm.startPrank(DAI_WHALE);
    IERC20(DAI).transfer(user1, INITIAL_BALANCE);
    IERC20(DAI).transfer(user2, INITIAL_BALANCE);
    vm.stopPrank();
    
    // Fund contract with WETH liquidity from whale
    vm.prank(WETH_WHALE);
    IERC20(WETH).transfer(address(swapper), 50_000e18);
  }
  
  /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
  //////////////////////////////////////////////////////////////*/
  
  function test_fork_completeSwapFlow() external {
    // User1 provides DAI
    vm.startPrank(user1);
    IERC20(DAI).approve(address(swapper), DEPOSIT_AMOUNT);
    
    vm.expectEmit(true, true, false, false);
    emit ISwapperMVP.TokensProvided(user1, DEPOSIT_AMOUNT);
    swapper.provide(DEPOSIT_AMOUNT);
    vm.stopPrank();
    
    // User2 provides DAI
    vm.startPrank(user2);
    IERC20(DAI).approve(address(swapper), DEPOSIT_AMOUNT * 2);
    swapper.provide(DEPOSIT_AMOUNT * 2);
    vm.stopPrank();
    
    // Execute swap
    uint256 totalDeposited = DEPOSIT_AMOUNT * 3;
    vm.expectEmit(true, true, false, false);
    emit ISwapperMVP.SwapExecuted(totalDeposited, totalDeposited);
    swapper.swap();
    
    // Check contract balances after swap
    assertEq(IERC20(DAI).balanceOf(address(swapper)), totalDeposited);
    assertGe(IERC20(WETH).balanceOf(address(swapper)), totalDeposited);
    
    // Users withdraw WETH
    uint256 user1WethBefore = IERC20(WETH).balanceOf(user1);
    vm.prank(user1);
    swapper.withdraw();
    assertEq(IERC20(WETH).balanceOf(user1), user1WethBefore + DEPOSIT_AMOUNT);
    
    uint256 user2WethBefore = IERC20(WETH).balanceOf(user2);
    vm.prank(user2);
    swapper.withdraw();
    assertEq(IERC20(WETH).balanceOf(user2), user2WethBefore + DEPOSIT_AMOUNT * 2);
  }
  
  function test_fork_withdrawBeforeSwap() external {
    // User provides DAI
    vm.startPrank(user1);
    IERC20(DAI).approve(address(swapper), DEPOSIT_AMOUNT);
    swapper.provide(DEPOSIT_AMOUNT);
    
    // Withdraw before swap
    uint256 daiBefore = IERC20(DAI).balanceOf(user1);
    swapper.withdraw();
    vm.stopPrank();
    
    assertEq(IERC20(DAI).balanceOf(user1), daiBefore + DEPOSIT_AMOUNT);
    assertEq(swapper.deposits(user1), 0);
  }
  
  
  
  function test_fork_insufficientWethLiquidity() external {
    // Deploy new swapper with no WETH liquidity
    SwapperMVP noLiquiditySwapper = new SwapperMVP(DAI, WETH);
    
    // User provides DAI
    vm.startPrank(user1);
    IERC20(DAI).approve(address(noLiquiditySwapper), DEPOSIT_AMOUNT);
    noLiquiditySwapper.provide(DEPOSIT_AMOUNT);
    vm.stopPrank();
    
    // Swap should fail due to insufficient liquidity
    vm.expectRevert();
    noLiquiditySwapper.swap();
  }
}