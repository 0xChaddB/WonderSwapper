// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SwapperMVP, ISwapperMVP} from "src/SwapperMVP.sol";
import {MockDAI} from "../mocks/MockDAI.sol";
import {MockWETH} from "../mocks/MockWETH.sol";

/**
 * @notice Simplified unit tests that follow Wonderland basic principles 
 * @dev Uses real mock tokens instead of vm.mockCall for clarity and simplicity
 */
contract SwapperMVPTest is Test {
    SwapperMVP public swapper;
    MockDAI public dai;
    MockWETH public weth;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    uint256 constant DEPOSIT_AMOUNT = 1000e18;
    
    function setUp() public {
        // Deploy mock tokens
        dai = new MockDAI();
        weth = new MockWETH();
        
        // Deploy swapper
        swapper = new SwapperMVP(address(dai), address(weth));
        
        // Setup test environment
        dai.mint(user1, 10000e18);
        dai.mint(user2, 10000e18);
        weth.mint(address(swapper), 50000e18); // Liquidity
    }
    
    /*//////////////////////////////////////////////////////////////
                            PROVIDE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_provide_revertsWhenAmountIsZero() external {
        vm.expectRevert(
            abi.encodeWithSelector(ISwapperMVP.SwapperMVP__InvalidAmount.selector, 0)
        );
        swapper.provide(0);
    }
    
    function test_provide_revertsWhenSwapAlreadyExecuted() external {
        // Setup and execute swap
        _userDeposit(user1, DEPOSIT_AMOUNT);
        swapper.swap();
        
        // Try to provide after swap
        vm.prank(user1);
        vm.expectRevert(ISwapperMVP.SwapperMVP__InvalidState.selector);
        swapper.provide(DEPOSIT_AMOUNT);
    }
    
    function test_provide_revertsWhenInsufficientAllowance() external {
        vm.prank(user1);
        // No approval given
        vm.expectRevert(); // ERC20 will revert
        swapper.provide(DEPOSIT_AMOUNT);
    }
    
    function test_provide_successfulDeposit() external {
        vm.startPrank(user1);
        dai.approve(address(swapper), DEPOSIT_AMOUNT);
        
        vm.expectEmit(true, true, false, false);
        emit ISwapperMVP.TokensProvided(user1, DEPOSIT_AMOUNT);
        
        swapper.provide(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(swapper.deposits(user1), DEPOSIT_AMOUNT);
        assertEq(swapper.totalDeposited(), DEPOSIT_AMOUNT);
    }
    
    function testFuzz_provide_multipleDeposits(uint256 amount1, uint256 amount2) external {
        amount1 = bound(amount1, 1, 5000e18);
        amount2 = bound(amount2, 1, 5000e18);
        
        vm.startPrank(user1);
        dai.approve(address(swapper), amount1 + amount2);
        
        swapper.provide(amount1);
        swapper.provide(amount2);
        vm.stopPrank();
        
        assertEq(swapper.deposits(user1), amount1 + amount2);
    }
    
    /*//////////////////////////////////////////////////////////////
                              SWAP TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_swap_revertsWhenAlreadySwapped() external {
        _userDeposit(user1, DEPOSIT_AMOUNT);
        swapper.swap();
        
        vm.expectRevert(ISwapperMVP.SwapperMVP__InvalidState.selector);
        swapper.swap();
    }
    
    function test_swap_revertsWhenNoDeposits() external {
        vm.expectRevert(ISwapperMVP.SwapperMVP__NoTokensToSwap.selector);
        swapper.swap();
    }
    
    function test_swap_revertsWhenInsufficientLiquidity() external {
        // Deposit more than available liquidity
        uint256 bigAmount = 100000e18;
        dai.mint(user1, bigAmount);
        
        vm.startPrank(user1);
        dai.approve(address(swapper), bigAmount);
        swapper.provide(bigAmount);
        vm.stopPrank();
        
        vm.expectRevert();
        swapper.swap();
    }
    
    function test_swap_successfulExecution() external {
        uint256 totalAmount = DEPOSIT_AMOUNT * 2;
        _userDeposit(user1, DEPOSIT_AMOUNT);
        _userDeposit(user2, DEPOSIT_AMOUNT);
        
        vm.expectEmit(true, true, false, false);
        emit ISwapperMVP.SwapExecuted(totalAmount, totalAmount);
        
        swapper.swap();
        
        assertTrue(swapper.hasSwapped());
    }
    
    /*//////////////////////////////////////////////////////////////
                           WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_withdraw_revertsWhenNotSwapped() external {
        _userDeposit(user1, DEPOSIT_AMOUNT);
        
        vm.prank(user1);
        vm.expectRevert(ISwapperMVP.SwapperMVP__InvalidState.selector);
        swapper.withdraw();
    }
    
    function test_withdraw_revertsWhenNoDeposit() external {
        _userDeposit(user1, DEPOSIT_AMOUNT);
        swapper.swap();
        
        vm.prank(user2); // user2 never deposited
        vm.expectRevert(ISwapperMVP.SwapperMVP_NoTokenToWithdraw.selector);
        swapper.withdraw();
    }
    
    function test_withdraw_successfulWithdrawal() external {
        _userDeposit(user1, DEPOSIT_AMOUNT);
        swapper.swap();
        
        uint256 balanceBefore = weth.balanceOf(user1);
        
        vm.expectEmit(true, true, false, false);
        emit ISwapperMVP.TokensWithdrawn(user1, DEPOSIT_AMOUNT);
        
        vm.prank(user1);
        swapper.withdraw();
        
        assertEq(swapper.deposits(user1), 0);
        assertEq(weth.balanceOf(user1), balanceBefore + DEPOSIT_AMOUNT);
    }
    
    function test_withdraw_cannotWithdrawTwice() external {
        _userDeposit(user1, DEPOSIT_AMOUNT);
        swapper.swap();
        
        vm.startPrank(user1);
        swapper.withdraw();
        
        vm.expectRevert(ISwapperMVP.SwapperMVP_NoTokenToWithdraw.selector);
        swapper.withdraw();
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/
    
    function _userDeposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        dai.approve(address(swapper), amount);
        swapper.provide(amount);
        vm.stopPrank();
    }
}