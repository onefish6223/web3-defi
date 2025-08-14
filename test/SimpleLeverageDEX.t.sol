// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/simpleleverageDEX/SimpleLeverageDEX.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev 用于测试的模拟USDC代币
 */
 // wake-disable
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10**6); // 铸造100万USDC（6位小数）
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title SimpleLeverageDEXTest
 * @dev SimpleLeverageDEX合约的完整测试套件
 */
contract SimpleLeverageDEXTest is Test {
    SimpleLeverageDEX public dex;
    MockUSDC public usdc;
    
    // 测试用户地址
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public liquidator = address(0x3);
    
    // 测试常量
    uint256 constant INITIAL_VETH = 1000 ether;     // 初始虚拟ETH数量
    uint256 constant INITIAL_VUSDC = 2000000 * 10**6; // 初始虚拟USDC数量（200万USDC）
    uint256 constant USER_USDC_BALANCE = 10000 * 10**6; // 用户初始USDC余额（1万USDC）
    
    function setUp() public {
        // 部署模拟USDC代币
        usdc = new MockUSDC();
        
        // 部署SimpleLeverageDEX合约
        dex = new SimpleLeverageDEX(INITIAL_VETH, INITIAL_VUSDC, address(usdc));
        
        // 为测试用户分配USDC
        usdc.mint(user1, USER_USDC_BALANCE);
        usdc.mint(user2, USER_USDC_BALANCE);
        usdc.mint(liquidator, USER_USDC_BALANCE);
        
        // 给DEX合约转入一些USDC用于支付用户平仓
        usdc.mint(address(dex), 100000 * 10**6); // 给合约10万USDC
        
        // 用户授权DEX合约使用他们的USDC
        vm.prank(user1);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(user2);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(liquidator);
        usdc.approve(address(dex), type(uint256).max);
    }
    
    // ==================== 基础功能测试 ====================
    
    /**
     * @dev 测试合约初始化状态
     */
    function test_InitialState() public {
        assertEq(dex.vETHAmount(), INITIAL_VETH);
        assertEq(dex.vUSDCAmount(), INITIAL_VUSDC);
        assertEq(dex.vK(), INITIAL_VETH * INITIAL_VUSDC);
        assertEq(address(dex.USDC()), address(usdc));
    }
    
    // ==================== openPosition函数测试 ====================
    
    /**
     * @dev 测试开多仓
     */
    function test_OpenLongPosition() public {
        uint256 margin = 1000 * 10**6; // 1000 USDC保证金
        uint256 leverage = 2; // 2倍杠杆
        bool isLong = true;
        
        uint256 initialBalance = usdc.balanceOf(user1);
        
        vm.prank(user1);
        dex.openPosition(margin, leverage, isLong);
        
        // 检查用户USDC余额减少
        assertEq(usdc.balanceOf(user1), initialBalance - margin);
        
        // 检查头寸信息
        (uint256 storedMargin, uint256 borrowedAmount, int256 position) = dex.positions(user1);
        assertTrue(position > 0); // 多仓position为正
        assertEq(storedMargin, margin);
        assertTrue(borrowedAmount > 0); // 有借入金额
    }
    
    /**
     * @dev 测试开空仓
     */
    function test_OpenShortPosition() public {
        uint256 margin = 1000 * 10**6; // 1000 USDC保证金
        uint256 leverage = 3; // 3倍杠杆
        bool isLong = false;
        
        uint256 initialBalance = usdc.balanceOf(user1);
        
        vm.prank(user1);
        dex.openPosition(margin, leverage, isLong);
        
        // 检查用户USDC余额减少
        assertEq(usdc.balanceOf(user1), initialBalance - margin);
        
        // 检查头寸信息
        (uint256 storedMargin, uint256 borrowedAmount, int256 position) = dex.positions(user1);
        assertTrue(position < 0); // 空仓position为负
        assertEq(storedMargin, margin);
        assertTrue(borrowedAmount > 0); // 有借入金额
    }
    
    /**
     * @dev 测试开仓参数验证
     */
    function test_OpenPosition_InvalidParameters() public {
        // 测试保证金为0
        vm.prank(user1);
        vm.expectRevert("Margin must be positive");
        dex.openPosition(0, 2, true);
        
        // 测试杠杆为0
        vm.prank(user1);
        vm.expectRevert("Leverage must be positive");
        dex.openPosition(1000 * 10**6, 0, true);
    }
    
    /**
     * @dev 测试重复开仓
     */
    function test_OpenPosition_AlreadyHasPosition() public {
        // 先开一个仓
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 2, true);
        
        // 尝试再开一个仓，应该失败
        vm.prank(user1);
        vm.expectRevert("Position already open");
        dex.openPosition(500 * 10**6, 3, false);
    }
    
    // ==================== calculatePnL函数测试 ====================
    
    /**
     * @dev 测试计算盈亏 - 无头寸
     */
    function test_CalculatePnL_NoPosition() public {
        int256 pnl = dex.calculatePnL(user1);
        assertEq(pnl, 0);
    }
    
    /**
     * @dev 测试计算盈亏 - 多仓
     */
    function test_CalculatePnL_LongPosition() public {
        // 开多仓
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 2, true);
        
        // 计算盈亏（刚开仓时可能有盈利或亏损，取决于价格变化）
        int256 pnl = dex.calculatePnL(user1);
        // PnL应该在合理范围内
        assertTrue(pnl > -int256(5000 * 10**6)); // 亏损不应该超过5000 USDC
        assertTrue(pnl < int256(5000 * 10**6)); // 盈利也不应该超过5000 USDC
    }
    
    /**
     * @dev 测试计算盈亏 - 空仓
     */
    function test_CalculatePnL_ShortPosition() public {
        // 开空仓
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 2, false);
        
        // 计算盈亏（刚开仓时应该接近0，可能有小幅亏损由于滑点）
        int256 pnl = dex.calculatePnL(user1);
        // 由于滑点，刚开仓时通常会有亏损，但不应该太大
        assertTrue(pnl < 0); // 由于滑点应该有亏损
        assertTrue(pnl > -int256(5000 * 10**6)); // 亏损不应该超过5000 USDC
    }
    
    // ==================== closePosition函数测试 ====================
    
    /**
     * @dev 测试关闭多仓
     */
    function test_ClosePosition_Long() public {
        uint256 margin = 1000 * 10**6;
        
        // 开多仓
        vm.prank(user1);
        dex.openPosition(margin, 2, true);
        
        uint256 balanceBeforeClose = usdc.balanceOf(user1);
        
        // 关闭头寸
        vm.prank(user1);
        dex.closePosition();
        
        // 检查头寸已清除
        (uint256 storedMargin, uint256 borrowedAmount, int256 position) = dex.positions(user1);
        assertEq(position, 0);
        assertEq(storedMargin, 0);
        assertEq(borrowedAmount, 0);
        
        // 检查用户收到了一些资金（可能少于保证金由于滑点）
        assertTrue(usdc.balanceOf(user1) > balanceBeforeClose);
    }
    
    /**
     * @dev 测试关闭空仓
     */
    function test_ClosePosition_Short() public {
        uint256 margin = 1000 * 10**6;
        
        // 开空仓
        vm.prank(user1);
        dex.openPosition(margin, 2, false);
        
        uint256 balanceBeforeClose = usdc.balanceOf(user1);
        
        // 关闭头寸
        vm.prank(user1);
        dex.closePosition();
        
        // 检查头寸已清除
        (uint256 storedMargin, uint256 borrowedAmount, int256 position) = dex.positions(user1);
        assertEq(position, 0);
        assertEq(storedMargin, 0);
        assertEq(borrowedAmount, 0);
        
        // 检查用户余额变化（可能由于亏损过大，没有收到资金）
        // 在高杠杆情况下，由于滑点可能导致亏损超过保证金
        uint256 balanceAfterClose = usdc.balanceOf(user1);
        assertTrue(balanceAfterClose >= balanceBeforeClose); // 余额不应该减少
    }
    
    /**
     * @dev 测试关闭不存在的头寸
     */
    function test_ClosePosition_NoPosition() public {
        vm.prank(user1);
        vm.expectRevert("No open position");
        dex.closePosition();
    }
    
    // ==================== liquidatePosition函数测试 ====================
    
    /**
     * @dev 测试清算条件检查
     */
    function test_LiquidatePosition_NotLiquidatable() public {
        // 开一个正常的仓位
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 2, true);
        
        // 尝试清算，应该失败（因为还没达到清算条件）
        vm.prank(liquidator);
        vm.expectRevert("Position not liquidatable");
        dex.liquidatePosition(user1);
    }
    
    /**
     * @dev 测试不能清算自己的头寸
     */
    function test_LiquidatePosition_CannotLiquidateOwn() public {
        // 开仓
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 2, true);
        
        // 尝试清算自己的头寸
        vm.prank(user1);
        vm.expectRevert("Cannot liquidate own position");
        dex.liquidatePosition(user1);
    }
    
    /**
     * @dev 测试清算不存在的头寸
     */
    function test_LiquidatePosition_NoPosition() public {
        vm.prank(liquidator);
        vm.expectRevert("No open position");
        dex.liquidatePosition(user1);
    }
    
    /**
     * @dev 模拟清算场景（通过操纵价格）
     */
    function test_LiquidatePosition_Success() public {
        uint256 margin = 1000 * 10**6;
        
        // user1开高杠杆多仓
        vm.prank(user1);
        dex.openPosition(margin, 10, true); // 10倍杠杆，风险较高
        
        // user2开大量空仓来推动价格下跌
        vm.prank(user2);
        dex.openPosition(5000 * 10**6, 2, false); // 大额空仓
        
        // 检查user1是否可以被清算
        int256 pnl = dex.calculatePnL(user1);
        if (pnl < 0 && uint256(-pnl) > (margin * 80) / 100) {
            uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);
            
            // 执行清算
            vm.prank(liquidator);
            dex.liquidatePosition(user1);
            
            // 检查清算人获得了奖励
            assertTrue(usdc.balanceOf(liquidator) > liquidatorBalanceBefore);
            
            // 检查被清算用户的头寸已清除
            (uint256 storedMargin, uint256 borrowedAmount, int256 position) = dex.positions(user1);
            assertEq(position, 0);
            assertEq(storedMargin, 0);
            assertEq(borrowedAmount, 0);
        }
    }
    
    // ==================== 综合场景测试 ====================
    
    /**
     * @dev 测试多用户交易场景
     */
    function test_MultiUserTrading() public {
        // user1开多仓
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 3, true);
        
        // user2开空仓
        vm.prank(user2);
        dex.openPosition(1500 * 10**6, 2, false);
        
        // 检查两个用户都有头寸
        (, , int256 pos1) = dex.positions(user1);
        (, , int256 pos2) = dex.positions(user2);
        assertTrue(pos1 > 0); // user1多仓
        assertTrue(pos2 < 0); // user2空仓
        
        // 计算盈亏
        int256 pnl1 = dex.calculatePnL(user1);
        int256 pnl2 = dex.calculatePnL(user2);
        
        // 由于是相反方向的交易，一般来说一个盈利一个亏损
        // 但由于滑点，两个都可能亏损
        assertTrue(pnl1 != 0 || pnl2 != 0); // 至少有一个有盈亏
    }
    
    /**
     * @dev 测试虚拟池子状态变化
     */
    function test_VirtualPoolStateChanges() public {
        uint256 initialVETH = dex.vETHAmount();
        uint256 initialVUSDC = dex.vUSDCAmount();
        uint256 vK = dex.vK();
        
        // 开多仓（买入ETH）
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 2, true);
        
        // 检查虚拟池子状态变化
        uint256 newVETH = dex.vETHAmount();
        uint256 newVUSDC = dex.vUSDCAmount();
        
        // 买入ETH后，池子中ETH减少，USDC增加
        assertTrue(newVETH < initialVETH);
        assertTrue(newVUSDC > initialVUSDC);
        
        // 恒定乘积应该保持不变（考虑精度误差）
        uint256 newK = newVETH * newVUSDC;
        assertTrue(newK >= vK * 99 / 100); // 允许1%的精度误差
        assertTrue(newK <= vK * 101 / 100);
    }
    
    /**
     * @dev 测试边界条件 - 最小保证金
     */
    function test_MinimumMargin() public {
        // 测试非常小的保证金
        vm.prank(user1);
        dex.openPosition(1, 2, true); // 1 wei保证金
        
        (uint256 margin, uint256 borrowed, int256 position) = dex.positions(user1);
        assertEq(margin, 1);
        assertTrue(position != 0);
        assertTrue(borrowed > 0);
    }
    
    /**
     * @dev 测试最大杠杆
     */
    function test_MaximumLeverage() public {
        vm.prank(user1);
        dex.openPosition(1000 * 10**6, 10, true); // 10倍杠杆（最大值）
        
        (uint256 margin, uint256 borrowed, int256 position) = dex.positions(user1);
        assertEq(margin, 1000 * 10**6);
        assertTrue(position != 0);
        // 借入金额应该约等于保证金的9倍（10倍杠杆 - 1倍保证金）
        assertTrue(borrowed >= margin * 8); // 考虑滑点，至少8倍
    }
}