// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SwapperMVP, ISwapperMVP} from "src/SwapperMVP.sol";
import {MockDAI} from "./mocks/MockDAI.sol";
import {MockWETH} from "./mocks/MockWETH.sol";

contract SwapperMVPTest is Test {

    SwapperMVP public swapper;
    MockDAI public dai;
    MockWETH public weth;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");   

    function setUp() external {
        dai = new MockDAI();
        weth = new MockWETH();
        swapper = new SwapperMVP(address(dai), address(weth));

        dai.mint(user1, 10000e18);
        dai.mint(user2, 5000e18);

        // Governor fund toToken Liquidity (WETH)
        weth.mint(address(swapper), 20000e18);

    }

    function testUserCanProvide() external {
        vm.startPrank(user1);
        // User approves
        dai.approve(address(swapper), 1000e18);
        // User provides
        vm.expectEmit(true, true, false, false);
        emit ISwapperMVP.TokensProvided(user1, 1000e18);
        swapper.provide(1000e18);
        // Verify deposit
        assertEq(swapper.deposits(user1), 1000e18);
        assertEq(swapper.totalDeposited(), 1000e18);
        
        vm.stopPrank();
    }
    
}