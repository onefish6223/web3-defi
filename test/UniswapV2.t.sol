// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/uniswapv2/UniswapV2Factory.sol";
import "../src/uniswapv2/UniswapV2Router02.sol";
import "../src/uniswapv2/UniswapV2Pair.sol";
import {MockERC20} from "../src/MockERC20.sol";

/**
 * @title UniswapV2Test
 * @dev UniswapV2合约测试
 * 测试工厂、路由器和交易对的核心功能
 */
 // wake-disable
contract UniswapV2Test is Test {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public weth;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant LIQUIDITY_AMOUNT = 10000 * 10**18;
    
    /**
     * @dev 测试设置
     */
    function setUp() public {
        // 部署代币
        tokenA = new MockERC20("Token A", "TKA", INITIAL_SUPPLY);
        tokenB = new MockERC20("Token B", "TKB", INITIAL_SUPPLY);
        weth = new MockERC20("Wrapped Ether", "WETH", INITIAL_SUPPLY);
        
        // 部署工厂
        factory = new UniswapV2Factory(address(this));
        
        // 部署路由器
        router = new UniswapV2Router02(address(factory), address(weth));
        
        // 给测试账户分配代币
        tokenA.mint(alice, INITIAL_SUPPLY);
        tokenB.mint(alice, INITIAL_SUPPLY);
        weth.mint(alice, INITIAL_SUPPLY);
        
        tokenA.mint(bob, INITIAL_SUPPLY);
        tokenB.mint(bob, INITIAL_SUPPLY);
        weth.mint(bob, INITIAL_SUPPLY);
        
        // 给路由器授权
        vm.startPrank(alice);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }
    
    /**
     * @dev 测试工厂部署
     */
    function testFactoryDeployment() public {
        assertEq(factory.feeToSetter(), address(this));
        assertEq(factory.feeTo(), address(0));
        assertEq(factory.allPairsLength(), 0);
    }
    
    /**
     * @dev 测试创建交易对
     */
    function testCreatePair() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.allPairs(0), pair);
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair);
        
        // 验证交易对合约
        UniswapV2Pair pairContract = UniswapV2Pair(pair);
        assertEq(pairContract.factory(), address(factory));
        
        (address token0, address token1) = address(tokenA) < address(tokenB) 
            ? (address(tokenA), address(tokenB)) 
            : (address(tokenB), address(tokenA));
        assertEq(pairContract.token0(), token0);
        assertEq(pairContract.token1(), token1);
    }
    
    /**
     * @dev 测试重复创建交易对失败
     */
    function testCreatePairTwiceFails() public {
        factory.createPair(address(tokenA), address(tokenB));
        
        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(tokenA), address(tokenB));
        
        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(tokenB), address(tokenA));
    }
    
    /**
     * @dev 测试添加流动性
     */
    function testAddLiquidity() public {
        vm.startPrank(alice);
        
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        assertEq(amountA, LIQUIDITY_AMOUNT);
        assertEq(amountB, LIQUIDITY_AMOUNT);
        assertGt(liquidity, 0);
        
        // 验证交易对已创建
        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0));
        
        // 验证流动性代币余额
        assertEq(UniswapV2Pair(pair).balanceOf(alice), liquidity);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试移除流动性
     */
    function testRemoveLiquidity() public {
        vm.startPrank(alice);
        
        // 先添加流动性
        (, , uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair(pair).approve(address(router), liquidity);
        
        uint256 balanceABefore = tokenA.balanceOf(alice);
        uint256 balanceBBefore = tokenB.balanceOf(alice);
        
        // 移除流动性
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(tokenA.balanceOf(alice), balanceABefore + amountA);
        assertEq(tokenB.balanceOf(alice), balanceBBefore + amountB);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试代币交换
     */
    function testSwapExactTokensForTokens() public {
        vm.startPrank(alice);
        
        // 先添加流动性
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
        
        vm.startPrank(bob);
        
        uint256 swapAmount = 1000 * 10**18;
        uint256 balanceBBefore = tokenB.balanceOf(bob);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // 执行交换
        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            bob,
            block.timestamp + 1 hours
        );
        
        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(tokenB.balanceOf(bob), balanceBBefore + amounts[1]);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试获取输出数量
     */
    function testGetAmountOut() public {
        uint256 amountIn = 1000;
        uint256 reserveIn = 10000;
        uint256 reserveOut = 10000;
        
        uint256 amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        
        // 验证计算公式：amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
        uint256 expected = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997);
        assertEq(amountOut, expected);
    }
    
    /**
     * @dev 测试获取输入数量
     */
    function testGetAmountIn() public {
        uint256 amountOut = 900;
        uint256 reserveIn = 10000;
        uint256 reserveOut = 10000;
        
        uint256 amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
        
        // 验证计算公式：amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
        uint256 expected = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1;
        assertEq(amountIn, expected);
    }
    
    /**
     * @dev 测试设置手续费接收地址
     */
    function testSetFeeTo() public {
        address feeReceiver = address(0x999);
        
        factory.setFeeTo(feeReceiver);
        assertEq(factory.feeTo(), feeReceiver);
    }
    
    /**
     * @dev 测试非授权用户无法设置手续费
     */
    function testSetFeeToUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeTo(address(0x999));
    }
    
    /**
     * @dev 测试设置手续费设置者
     */
    function testSetFeeToSetter() public {
        address newSetter = address(0x888);
        
        factory.setFeeToSetter(newSetter);
        assertEq(factory.feeToSetter(), newSetter);
    }
    
    /**
     * @dev 测试交易对同步
     */
    function testPairSync() public {
        vm.startPrank(alice);
        
        // 添加流动性
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        address pair = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pairContract = UniswapV2Pair(pair);
        
        // 直接向交易对转账（模拟外部转账）
        tokenA.transfer(pair, 1000 * 10**18);
        
        // 同步储备量
        pairContract.sync();
        
        (uint112 reserve0, uint112 reserve1,) = pairContract.getReserves();
        assertGt(reserve0, 0);
        assertGt(reserve1, 0);
        
        vm.stopPrank();
    }
}