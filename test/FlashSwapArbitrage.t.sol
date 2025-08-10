// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import {UniswapV2Factory} from "../src/uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../src/uniswapv2/UniswapV2Router02.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "../src/WETH.sol";
import "../src/uniswapv2/interfaces/IUniswapV2Pair.sol";

/**
 * @title FlashSwapArbitrageTest
 * @dev 测试闪电兑换套利合约
 */
  // wake-disable
contract FlashSwapArbitrageTest is Test {
    MyToken public tokenA;
    MyToken public tokenB;
    WETH public weth;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    UniswapV2Router02 public routerA;
    UniswapV2Router02 public routerB;
    FlashSwapArbitrage public arbitrage;
    
    address public pairA;
    address public pairB;
    
    address public deployer = makeAddr("deployer");
    address public user = makeAddr("user");
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // 部署基础合约
        weth = new WETH();
        tokenA = new MyToken("Token A", "TKA", 18, 1000000, deployer);
        tokenB = new MyToken("Token B", "TKB", 18, 1000000, deployer);
        
        // 部署两个Uniswap工厂
        factoryA = new UniswapV2Factory(deployer);
        factoryB = new UniswapV2Factory(deployer);
        
        // 部署路由器
        routerA = new UniswapV2Router02(address(factoryA), address(weth));
        routerB = new UniswapV2Router02(address(factoryB), address(weth));
        
        // 创建交易对
        pairA = factoryA.createPair(address(tokenA), address(tokenB));
        pairB = factoryB.createPair(address(tokenA), address(tokenB));
        
        // 添加流动性到池子A（比例 1:2）
        uint256 amountA1 = 100000 * 10**18;
        uint256 amountB1 = 200000 * 10**18;
        
        tokenA.approve(address(routerA), amountA1);
        tokenB.approve(address(routerA), amountB1);
        
        routerA.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA1,
            amountB1,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        
        // 添加流动性到池子B（比例 1:3，创造更大价差）
        uint256 amountA2 = 100000 * 10**18;
        uint256 amountB2 = 300000 * 10**18;
        
        tokenA.approve(address(routerB), amountA2);
        tokenB.approve(address(routerB), amountB2);
        
        routerB.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA2,
            amountB2,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        
        // 部署套利合约
        arbitrage = new FlashSwapArbitrage(
            address(factoryA),
            address(factoryB),
            deployer
        );
        
        vm.stopPrank();
    }
    
    function testDeployment() public {
        assertEq(arbitrage.factoryA(), address(factoryA));
        assertEq(arbitrage.factoryB(), address(factoryB));
        assertEq(arbitrage.owner(), deployer);
    }
    
    function testPoolPrices() public view {
        // 检查池子A的储备
        (uint256 reserve0A, uint256 reserve1A,) = IUniswapV2Pair(pairA).getReserves();
        console.log("Pool A reserves:", reserve0A, reserve1A);
        
        // 检查池子B的储备
        (uint256 reserve0B, uint256 reserve1B,) = IUniswapV2Pair(pairB).getReserves();
        console.log("Pool B reserves:", reserve0B, reserve1B);
        
        // 验证价差存在
        assertTrue(reserve0A > 0 && reserve1A > 0);
        assertTrue(reserve0B > 0 && reserve1B > 0);
    }
    
    function testExecuteArbitrage() public {
        vm.startPrank(deployer);
        
        // 记录初始余额
        uint256 initialBalanceA = arbitrage.getTokenBalance(address(tokenA));
        uint256 initialBalanceB = arbitrage.getTokenBalance(address(tokenB));
        
        console.log("Initial balance A:", initialBalanceA);
        console.log("Initial balance B:", initialBalanceB);
        
        // 执行套利
        uint256 borrowAmount = 10 * 10**18; // 借入10个Token A
        
        // 先检查价格差异
        console.log("Testing arbitrage opportunity...");
        
        arbitrage.executeArbitrage(
            address(tokenA),
            address(tokenB),
            borrowAmount,
            true
        );
        
        // 检查套利后的余额
        uint256 finalBalanceA = arbitrage.getTokenBalance(address(tokenA));
        uint256 finalBalanceB = arbitrage.getTokenBalance(address(tokenB));
        
        console.log("Final balance A:", finalBalanceA);
        console.log("Final balance B:", finalBalanceB);
        
        // 验证有利润产生
        assertTrue(finalBalanceA > initialBalanceA || finalBalanceB > initialBalanceB);
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanExecute() public {
        vm.startPrank(user);
        
        vm.expectRevert();
        arbitrage.executeArbitrage(
            address(tokenA),
            address(tokenB),
            1000 * 10**18,
            true
        );
        
        vm.stopPrank();
    }
    
    function testWithdrawProfit() public {
        vm.startPrank(deployer);
        
        // 先执行套利获得利润
        arbitrage.executeArbitrage(
            address(tokenA),
            address(tokenB),
            1000 * 10**18,
            true
        );
        
        uint256 profitA = arbitrage.getTokenBalance(address(tokenA));
        uint256 profitB = arbitrage.getTokenBalance(address(tokenB));
        
        if (profitA > 0) {
            uint256 beforeBalance = tokenA.balanceOf(deployer);
            arbitrage.withdrawProfit(address(tokenA), profitA);
            uint256 afterBalance = tokenA.balanceOf(deployer);
            
            assertEq(afterBalance - beforeBalance, profitA);
        }
        
        if (profitB > 0) {
            uint256 beforeBalance = tokenB.balanceOf(deployer);
            arbitrage.withdrawProfit(address(tokenB), profitB);
            uint256 afterBalance = tokenB.balanceOf(deployer);
            
            assertEq(afterBalance - beforeBalance, profitB);
        }
        
        vm.stopPrank();
    }
    
    function testRevertWhenArbitrageWithIdenticalTokens() public {
        vm.startPrank(deployer);
        
        vm.expectRevert("FlashSwap: IDENTICAL_TOKENS");
        arbitrage.executeArbitrage(
            address(tokenA),
            address(tokenA), // 相同的代币
            1000 * 10**18,
            true
        );
        
        vm.stopPrank();
    }
    
    function testRevertWhenArbitrageWithZeroAmount() public {
        vm.startPrank(deployer);
        
        vm.expectRevert("FlashSwap: INVALID_AMOUNT");
        arbitrage.executeArbitrage(
            address(tokenA),
            address(tokenB),
            0, // 零数量
            true
        );
        
        vm.stopPrank();
    }
}