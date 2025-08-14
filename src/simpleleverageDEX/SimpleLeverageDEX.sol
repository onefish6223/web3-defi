// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SimpleLeverageDEX
 * @dev 基于虚拟自动做市商(vAMM)机制的简单杠杆交易所
 * @notice 该合约实现了一个极简的杠杆DEX，支持做多做空ETH/USDC交易对
 * 
 * 核心机制：
 * - 使用虚拟池子(vETH, vUSDC)进行价格发现，遵循恒定乘积公式 vK = vETH * vUSDC
 * - 用户提供保证金，系统提供杠杆资金
 * - 支持做多(买入虚拟ETH)和做空(卖出虚拟ETH)操作
 * - 当亏损超过保证金80%时触发清算机制
 */
contract SimpleLeverageDEX {
    using SafeERC20 for IERC20;

    // ============ 状态变量 ============
    
    /// @notice 虚拟池子的恒定乘积常数 K = vETH * vUSDC
    uint public vK;
    
    /// @notice 虚拟池子中的ETH数量
    uint public vETHAmount;
    
    /// @notice 虚拟池子中的USDC数量
    uint public vUSDCAmount;

    /// @notice USDC代币合约接口
    IERC20 public USDC;

    /**
     * @dev 用户头寸信息结构体
     * @param margin 用户提供的保证金数量(USDC)
     * @param borrowed 系统借给用户的资金数量(USDC)
     * @param position 虚拟ETH持仓数量，正数表示做多，负数表示做空
     */
    struct PositionInfo {
        uint256 margin;     // 保证金数量
        uint256 borrowed;   // 借入资金数量
        int256 position;    // 虚拟ETH持仓，正数=做多，负数=做空
    }
    
    /// @notice 用户地址到头寸信息的映射
    mapping(address => PositionInfo) public positions;

    // ============ 事件定义 ============
    
    /// @notice 开仓事件
    event PositionOpened(address indexed user, uint256 margin, uint256 leverage, bool isLong, int256 position);
    
    /// @notice 平仓事件
    event PositionClosed(address indexed user, int256 pnl, uint256 settlement);
    
    /// @notice 清算事件
    event PositionLiquidated(address indexed user, address indexed liquidator, uint256 reward);

    // ============ 构造函数 ============
    
    /**
     * @dev 构造函数，初始化虚拟池子和USDC代币
     * @param vEth 初始虚拟ETH数量
     * @param vUSDC 初始虚拟USDC数量
     * @param _usdc USDC代币合约地址
     */
    constructor(uint vEth, uint vUSDC, address _usdc) {
        require(vEth > 0 && vUSDC > 0, "Invalid pool amounts");
        require(_usdc != address(0), "Invalid USDC address");
        
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;  // 设置恒定乘积常数
        USDC = IERC20(_usdc);
    }

    // ============ 核心交易函数 ============

    /**
     * @dev 开启杠杆头寸
     * @param _margin 用户提供的保证金数量(USDC)
     * @param level 杠杆倍数(如2表示2倍杠杆)
     * @param long true=做多ETH, false=做空ETH
     * 
     * 工作原理：
     * 1. 用户提供保证金
     * 2. 系统计算总交易金额 = 保证金 * 杠杆倍数
     * 3. 借入资金 = 总交易金额 - 保证金
     * 4. 根据vAMM机制在虚拟池子中执行交易
     * 5. 记录用户的虚拟ETH持仓
     */
    function openPosition(uint256 _margin, uint level, bool long) external {
        // 检查用户是否已有开仓
        require(positions[msg.sender].position == 0, "Position already open");
        require(_margin > 0, "Margin must be positive");
        require(level > 0, "Leverage must be positive");

        PositionInfo storage pos = positions[msg.sender];

        // 从用户账户转入保证金
        USDC.safeTransferFrom(msg.sender, address(this), _margin);
        
        // 计算总交易金额和借入金额
        uint256 totalAmount = _margin * level;  // 总交易金额 = 保证金 * 杠杆倍数
        uint256 borrowAmount = totalAmount - _margin;  // 借入金额 = 总金额 - 保证金

        // 记录头寸基本信息
        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        // 根据vAMM机制计算虚拟ETH持仓
        if (long) {
            // === 做多逻辑：用USDC买入虚拟ETH ===
            // 原理：向虚拟池子注入USDC，根据恒定乘积公式计算能获得多少虚拟ETH
            // 公式：vK = vETH * vUSDC (恒定)
            // 新的vUSDC = 当前vUSDC + 投入的USDC数量
            // 新的vETH = vK / 新的vUSDC
            // 获得的vETH = 原vETH - 新的vETH
            
            uint256 newVUSDC = vUSDCAmount + totalAmount;
            uint256 newVETH = vK / newVUSDC;
            uint256 ethBought = vETHAmount - newVETH;
            
            // 记录做多头寸（正数）
            pos.position = int256(ethBought);
            
            // 更新虚拟池子状态
            vUSDCAmount = newVUSDC;
            vETHAmount = newVETH;
        } else {
            // === 做空逻辑：卖出虚拟ETH获得USDC ===
            // 原理：向虚拟池子注入虚拟ETH，根据恒定乘积公式计算能获得多少USDC
            // 首先需要将投入的USDC金额转换为等值的虚拟ETH数量
            // 当前价格 = vUSDC / vETH
            // 等值ETH数量 = 投入USDC / 当前价格 = (投入USDC * vETH) / vUSDC
            
            uint256 ethAmount = (totalAmount * vETHAmount) / vUSDCAmount;
            uint256 newVETH = vETHAmount + ethAmount;
            uint256 newVUSDC = vK / newVETH;
            
            // 记录做空头寸（负数）
            pos.position = -int256(ethAmount);
            
            // 更新虚拟池子状态
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        }
        
        // 发出开仓事件
        emit PositionOpened(msg.sender, _margin, level, long, pos.position);
    }

    /**
     * @dev 关闭头寸并结算
     * @notice 用户主动平仓，结算盈亏后返还资金
     * 
     * 工作原理：
     * 1. 计算当前头寸的盈亏
     * 2. 执行反向交易平仓（做多变卖出，做空变买入）
     * 3. 结算最终金额 = 保证金 + 盈亏
     * 4. 将结算金额转给用户
     * 5. 清除用户头寸记录
     */
    function closePosition() external {
        PositionInfo storage pos = positions[msg.sender];
        require(pos.position != 0, "No open position");
        
        // 计算当前头寸的盈亏
        int256 pnl = calculatePnL(msg.sender);
        
        // === 平仓操作：执行与开仓相反的交易 ===
        if (pos.position > 0) {
            // === 平多仓：卖出虚拟ETH ===
            // 将持有的虚拟ETH全部卖回给虚拟池子
            uint256 ethToSell = uint256(pos.position);
            uint256 newVETH = vETHAmount + ethToSell;  // 池子ETH增加
            uint256 newVUSDC = vK / newVETH;           // 根据恒定乘积计算新的USDC数量
            
            // 更新虚拟池子状态
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // === 平空仓：买入虚拟ETH ===
            // 买回之前卖出的虚拟ETH数量
            uint256 ethToBuy = uint256(-pos.position);
            // 计算买回这些ETH需要多少USDC（按当前价格）
            uint256 usdcCost = (ethToBuy * vUSDCAmount) / vETHAmount;
            uint256 newVUSDC = vUSDCAmount + usdcCost;  // 池子USDC增加
            uint256 newVETH = vK / newVUSDC;            // 根据恒定乘积计算新的ETH数量
            
            // 更新虚拟池子状态
            vUSDCAmount = newVUSDC;
            vETHAmount = newVETH;
        }
        
        // === 结算逻辑：计算最终返还给用户的金额 ===
        uint256 settlement = pos.margin;  // 基础结算金额为保证金
        
        if (pnl > 0) {
            // 盈利情况：保证金 + 盈利
            settlement += uint256(pnl);
        } else if (pnl < 0 && uint256(-pnl) < pos.margin) {
            // 亏损但未超过保证金：保证金 - 亏损
            settlement -= uint256(-pnl);
        } else {
            // 亏损超过保证金：无法返还任何资金
            settlement = 0;
        }
        
        // 将结算金额转给用户
        if (settlement > 0) {
            USDC.safeTransfer(msg.sender, settlement);
        }
        
        // 发出平仓事件
        emit PositionClosed(msg.sender, pnl, settlement);
        
        // 清除用户头寸记录
        delete positions[msg.sender];
    }

    /**
     * @dev 清算头寸
     * @notice 当用户头寸亏损过大时，任何人都可以清算该头寸
     * @param _user 被清算用户的地址
     * 
     * 清算条件：
     * - 清算人不能是被清算用户本人
     * - 用户必须有开仓头寸
     * - 头寸亏损必须超过保证金的80%
     * 
     * 清算流程：
     * 1. 验证清算条件
     * 2. 执行反向交易强制平仓
     * 3. 给清算人10%的保证金作为奖励
     * 4. 剩余保证金返还给被清算用户
     * 5. 清除被清算用户的头寸
     */
    function liquidatePosition(address _user) external {
        // === 基础验证 ===
        require(_user != msg.sender, "Cannot liquidate own position");
        PositionInfo storage position = positions[_user];
        require(position.position != 0, "No open position");
        
        // 计算被清算用户的当前盈亏
        int256 pnl = calculatePnL(_user);
        
        // === 清算条件检查 ===
        // 只有当亏损超过保证金的80%时才能被清算
        require(pnl < 0 && uint256(-pnl) > (position.margin * 80) / 100, "Position not liquidatable");
        
        // === 强制平仓操作：执行与开仓相反的交易 ===
        if (position.position > 0) {
            // === 清算多仓：强制卖出虚拟ETH ===
            // 将用户持有的虚拟ETH全部卖回给虚拟池子
            uint256 ethToSell = uint256(position.position);
            uint256 newVETH = vETHAmount + ethToSell;  // 池子ETH增加
            uint256 newVUSDC = vK / newVETH;           // 根据恒定乘积计算新的USDC数量
            
            // 更新虚拟池子状态
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // === 清算空仓：强制买入虚拟ETH ===
            // 强制买回用户之前卖出的虚拟ETH数量
            uint256 ethToBuy = uint256(-position.position);
            // 计算买回这些ETH需要多少USDC（按当前价格）
            uint256 usdcCost = (ethToBuy * vUSDCAmount) / vETHAmount;
            uint256 newVUSDC = vUSDCAmount + usdcCost;  // 池子USDC增加
            uint256 newVETH = vK / newVUSDC;            // 根据恒定乘积计算新的ETH数量
            
            // 更新虚拟池子状态
            vUSDCAmount = newVUSDC;
            vETHAmount = newVETH;
        }
        
        // === 清算奖励分配 ===
        // 清算人获得被清算用户保证金的10%作为奖励
        uint256 liquidationReward = (position.margin * 10) / 100;
        uint256 remainingMargin = position.margin - liquidationReward;
        
        // 转账清算奖励给清算人
        if (liquidationReward > 0) {
            USDC.safeTransfer(msg.sender, liquidationReward);
        }
        
        // === 剩余保证金处理 ===
        // 剩余的90%保证金返还给被清算用户
        if (remainingMargin > 0) {
            USDC.safeTransfer(_user, remainingMargin);
        }
        
        // 发出清算事件
        emit PositionLiquidated(_user, msg.sender, liquidationReward);
        
        // 清除被清算用户的头寸记录
        delete positions[_user];
    }

    /**
     * @dev 计算用户头寸的当前盈亏
     * @param user 用户地址
     * @return 盈亏金额（正数表示盈利，负数表示亏损）
     * 
     * 计算原理：
     * - 做多头寸：比较当前卖出价值与借入金额的差值
     * - 做空头寸：比较借入金额与当前买回成本的差值
     * 
     * 注意：这里计算的是基于当前虚拟池子价格的理论盈亏
     */
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory pos = positions[user];
        // 如果用户没有头寸，盈亏为0
        if (pos.position == 0) return 0;
        
        // 计算当前持仓的价值
        int256 currentValue;
        if (pos.position > 0) {
            // === 做多头寸盈亏计算 ===
            // 计算如果现在卖出所有虚拟ETH能得到多少USDC
            uint256 ethToSell = uint256(pos.position);
            uint256 newVETH = vETHAmount + ethToSell;     // 卖出后池子ETH数量
            uint256 newVUSDC = vK / newVETH;              // 根据恒定乘积计算新的USDC数量
            uint256 usdcReceived = vUSDCAmount - newVUSDC; // 用户能收到的USDC
            currentValue = int256(usdcReceived);
        } else {
            // === 做空头寸盈亏计算 ===
            // 计算如果现在买回所有虚拟ETH需要多少USDC
            uint256 ethToBuy = uint256(-pos.position);
            // 按当前价格计算买回成本
            uint256 usdcCost = (ethToBuy * vUSDCAmount) / vETHAmount;
            currentValue = -int256(usdcCost);
        }
        
        // === 最终盈亏计算 ===
        // PnL = 当前价值 - 借入资金
        // 正数表示盈利，负数表示亏损
        return currentValue - int256(pos.borrowed);
    }
}