// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SwapperMVP, ISwapperMVP} from "src/SwapperMVP.sol";
import {MockDAI} from "../mocks/MockDAI.sol";
import {MockWETH} from "../mocks/MockWETH.sol";

contract SwapperMVPIntegrationTest is Test {
    SwapperMVP public swapper;
    MockDAI public dai;
    MockWETH public weth;
    
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public governor = makeAddr("governor");
    
    uint256 public constant USER1_INITIAL_BALANCE = 10000e18;
    uint256 public constant USER2_INITIAL_BALANCE = 5000e18;
    uint256 public constant USER3_INITIAL_BALANCE = 2000e18;
    uint256 public constant GOVERNOR_LIQUIDITY = 20000e18;
    
    function setUp() public {
        // Deploy tokens
        dai = new MockDAI();
        weth = new MockWETH();
        
        // Deploy swapper
        swapper = new SwapperMVP(address(dai), address(weth));
        
        // Setup initial balances
        dai.mint(user1, USER1_INITIAL_BALANCE);
        dai.mint(user2, USER2_INITIAL_BALANCE);
        dai.mint(user3, USER3_INITIAL_BALANCE);
        
        // Governor provides liquidity
        weth.mint(address(swapper), GOVERNOR_LIQUIDITY);
    }
    
    /*//////////////////////////////////////////////////////////////
                            HAPPY PATHS
    //////////////////////////////////////////////////////////////*/
    
    function test_CompleteFlowSingleUser() external {
        uint256 depositAmount = 1000e18;
        
        // User1 approves and provides
        vm.startPrank(user1);
        dai.approve(address(swapper), depositAmount);
        swapper.provide(depositAmount);
        vm.stopPrank();
        
        // Anyone can trigger swap
        vm.prank(user2);
        swapper.swap();
        
        // User1 withdraws
        vm.prank(user1);
        swapper.withdraw();
        
        // Verify final state
        assertEq(dai.balanceOf(user1), USER1_INITIAL_BALANCE - depositAmount);
        assertEq(weth.balanceOf(user1), depositAmount); // 1:1 ratio
        assertEq(swapper.deposits(user1), 0);
    }
    
    function test_CompleteFlowMultipleUsers() external {
        uint256 user1Deposit = 1000e18;
        uint256 user2Deposit = 2000e18;
        uint256 user3Deposit = 500e18;
        uint256 totalDeposit = user1Deposit + user2Deposit + user3Deposit;
        
        // Users approve and provide
        vm.startPrank(user1);
        dai.approve(address(swapper), user1Deposit);
        swapper.provide(user1Deposit);
        vm.stopPrank();
        
        vm.startPrank(user2);
        dai.approve(address(swapper), user2Deposit);
        swapper.provide(user2Deposit);
        vm.stopPrank();
        
        vm.startPrank(user3);
        dai.approve(address(swapper), user3Deposit);
        swapper.provide(user3Deposit);
        vm.stopPrank();
        
        // Verify pre-swap state
        assertEq(swapper.totalDeposited(), totalDeposit);
        assertEq(dai.balanceOf(address(swapper)), totalDeposit);
        
        // Execute swap
        swapper.swap();
        
        // All users withdraw
        vm.prank(user1);
        swapper.withdraw();
        
        vm.prank(user2);
        swapper.withdraw();
        
        vm.prank(user3);
        swapper.withdraw();
        
        // Verify final balances
        assertEq(weth.balanceOf(user1), user1Deposit);
        assertEq(weth.balanceOf(user2), user2Deposit);
        assertEq(weth.balanceOf(user3), user3Deposit);
        
        // Verify all deposits cleared
        assertEq(swapper.deposits(user1), 0);
        assertEq(swapper.deposits(user2), 0);
        assertEq(swapper.deposits(user3), 0);
    }
    
    function test_MultipleDepositsFromSameUser() external {
        uint256 firstDeposit = 500e18;
        uint256 secondDeposit = 300e18;
        uint256 thirdDeposit = 200e18;
        uint256 totalDeposit = firstDeposit + secondDeposit + thirdDeposit;
        
        vm.startPrank(user1);
        dai.approve(address(swapper), totalDeposit);
        
        swapper.provide(firstDeposit);
        swapper.provide(secondDeposit);
        swapper.provide(thirdDeposit);
        vm.stopPrank();
        
        assertEq(swapper.deposits(user1), totalDeposit);
        assertEq(swapper.totalDeposited(), totalDeposit);
        
        // Complete the flow
        swapper.swap();
        
        vm.prank(user1);
        swapper.withdraw();
        
        assertEq(weth.balanceOf(user1), totalDeposit);
    }
    
    /*//////////////////////////////////////////////////////////////
                             SAD PATHS
    //////////////////////////////////////////////////////////////*/
    
    function test_UserCannotProvideWithoutApproval() external {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)")),
                address(swapper),
                0,
                1000e18
            )
        );
        swapper.provide(1000e18);
    }
    
    function test_UserCannotProvideMoreThanBalance() external {
        uint256 excessAmount = USER1_INITIAL_BALANCE + 1;
        
        vm.startPrank(user1);
        dai.approve(address(swapper), excessAmount);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")),
                user1,
                USER1_INITIAL_BALANCE,
                excessAmount
            )
        );
        swapper.provide(excessAmount);
        vm.stopPrank();
    }
    
    function test_CannotSwapWithInsufficientLiquidity() external {
        // Provide more than available liquidity
        uint256 excessDeposit = GOVERNOR_LIQUIDITY + 1;
        
        // Mint extra DAI to user1
        dai.mint(user1, excessDeposit);
        
        vm.startPrank(user1);
        dai.approve(address(swapper), excessDeposit);
        swapper.provide(excessDeposit);
        vm.stopPrank();
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ISwapperMVP.SwapperMVP_NotEnoughLiquidity.selector,
                GOVERNOR_LIQUIDITY,
                excessDeposit
            )
        );
        swapper.swap();
    }
    
    function test_LateUserCannotJoinAfterSwap() external {
        // User1 provides and swap happens
        vm.startPrank(user1);
        dai.approve(address(swapper), 1000e18);
        swapper.provide(1000e18);
        vm.stopPrank();
        
        swapper.swap();
        
        // User2 tries to join after swap
        vm.startPrank(user2);
        dai.approve(address(swapper), 1000e18);
        
        vm.expectRevert(ISwapperMVP.SwapperMVP__InvalidState.selector);
        swapper.provide(1000e18);
        vm.stopPrank();
    }
    
    function test_NonParticipantCannotWithdraw() external {
        // User1 provides
        vm.startPrank(user1);
        dai.approve(address(swapper), 1000e18);
        swapper.provide(1000e18);
        vm.stopPrank();
        
        swapper.swap();
        
        // User2 (who didn't provide) tries to withdraw
        vm.prank(user2);
        vm.expectRevert(ISwapperMVP.SwapperMVP_NoTokenToWithdraw.selector);
        swapper.withdraw();
    }
    
    /*//////////////////////////////////////////////////////////////
                          EDGE CASES
    //////////////////////////////////////////////////////////////*/
    
    function test_ExcessLiquidityRemainsInContract() external {
        uint256 depositAmount = 1000e18;
        uint256 totalLiquidity = GOVERNOR_LIQUIDITY;
        uint256 excessLiquidity = totalLiquidity - depositAmount;
        
        // User provides less than available liquidity
        vm.startPrank(user1);
        dai.approve(address(swapper), depositAmount);
        swapper.provide(depositAmount);
        vm.stopPrank();
        
        // Swap and withdraw
        swapper.swap();
        
        vm.prank(user1);
        swapper.withdraw();
        
        // Verify excess remains in contract
        assertEq(weth.balanceOf(address(swapper)), excessLiquidity);
        assertEq(dai.balanceOf(address(swapper)), depositAmount); // DAI is transferred to contract during provide
    }
    
    function test_GasEfficiencyWithManyUsers() external {
        uint256 userCount = 50;
        uint256 depositPerUser = 100e18;
        
        // Create and fund users
        for (uint256 i = 0; i < userCount; i++) {
            address user = address(uint160(uint256(keccak256(abi.encode("user", i)))));
            dai.mint(user, depositPerUser);
            
            vm.startPrank(user);
            dai.approve(address(swapper), depositPerUser);
            swapper.provide(depositPerUser);
            vm.stopPrank();
        }
        
        // Ensure enough liquidity
        weth.mint(address(swapper), userCount * depositPerUser);
        
        // Measure gas for swap
        uint256 gasBefore = gasleft();
        swapper.swap();
        uint256 gasUsed = gasBefore - gasleft();
        
        // Log gas usage
        emit log_named_uint("Gas used for swap with 50 users", gasUsed);
        
        // Verify swap succeeded
        assertTrue(swapper.hasSwapped());
        assertEq(swapper.totalDeposited(), userCount * depositPerUser);
    }
}