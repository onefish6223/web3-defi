// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interface/ILendingPool.sol";

/**
 * @title MockLendingPool
 * @dev 模拟借贷市场合约，用于演示质押池集成借贷功能
 * 简化版本，实际项目中应该集成真实的借贷协议如 Aave 或 Compound
 */
contract MockLendingPool is ILendingPool {
    // 年化利率 (5% APY)
    uint256 public constant ANNUAL_RATE = 5;
    
    // 用户存款信息
    struct DepositInfo {
        uint256 principal;      // 本金
        uint256 lastUpdateTime; // 上次更新时间
        uint256 accruedInterest; // 累积利息
    }
    
    // 用户存款映射
    mapping(address => DepositInfo) public deposits;
    
    // 总存款量
    uint256 public totalDeposits;
    
    // 事件
    event ETHDeposited(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed user, uint256 amount);
    event InterestAccrued(address indexed user, uint256 interest);
    
    /**
     * @dev 存入 ETH 到借贷市场
     */
    function depositETH() external payable override {
        require(msg.value > 0, "Cannot deposit 0 ETH");
        
        DepositInfo storage deposit = deposits[msg.sender];
        
        // 更新利息
        _updateInterest(msg.sender);
        
        // 增加本金
        deposit.principal += msg.value;
        totalDeposits += msg.value;
        
        emit ETHDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev 提取 ETH 从借贷市场
     * @param amount 提取数量
     */
    function withdrawETH(uint256 amount) external override {
        require(amount > 0, "Cannot withdraw 0 ETH");
        
        DepositInfo storage deposit = deposits[msg.sender];
        
        // 更新利息
        _updateInterest(msg.sender);
        
        uint256 totalBalance = deposit.principal + deposit.accruedInterest;
        require(totalBalance >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        // 先从利息中扣除，再从本金中扣除
        if (amount <= deposit.accruedInterest) {
            deposit.accruedInterest -= amount;
        } else {
            uint256 remainingAmount = amount - deposit.accruedInterest;
            deposit.accruedInterest = 0;
            deposit.principal -= remainingAmount;
            totalDeposits -= remainingAmount;
        }
        
        // 转账ETH
        payable(msg.sender).transfer(amount);
        
        emit ETHWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev 获取存款余额（包含利息）
     * @param user 用户地址
     * @return 存款余额
     */
    function getBalance(address user) external view override returns (uint256) {
        DepositInfo memory deposit = deposits[user];
        
        if (deposit.principal == 0) {
            return 0;
        }
        
        // 计算当前利息
        uint256 timeElapsed = block.timestamp - deposit.lastUpdateTime;
        uint256 currentInterest = _calculateInterest(deposit.principal, timeElapsed);
        
        return deposit.principal + deposit.accruedInterest + currentInterest;
    }
    
    /**
     * @dev 更新用户利息
     * @param user 用户地址
     */
    function _updateInterest(address user) internal {
        DepositInfo storage deposit = deposits[user];
        
        if (deposit.principal == 0) {
            deposit.lastUpdateTime = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - deposit.lastUpdateTime;
        if (timeElapsed > 0) {
            uint256 interest = _calculateInterest(deposit.principal, timeElapsed);
            deposit.accruedInterest += interest;
            deposit.lastUpdateTime = block.timestamp;
            
            if (interest > 0) {
                emit InterestAccrued(user, interest);
            }
        }
    }
    
    /**
     * @dev 计算利息
     * @param principal 本金
     * @param timeElapsed 经过的时间（秒）
     * @return 利息金额
     */
    function _calculateInterest(uint256 principal, uint256 timeElapsed) internal pure returns (uint256) {
        // 简化的利息计算：年化5%，按秒计算
        // interest = principal * rate * time / (365 * 24 * 3600 * 100)
        return (principal * ANNUAL_RATE * timeElapsed) / (365 * 24 * 3600 * 100);
    }
    
    /**
     * @dev 获取用户存款信息
     * @param user 用户地址
     * @return principal 本金
     * @return accruedInterest 累积利息
     * @return lastUpdateTime 上次更新时间
     */
    function getDepositInfo(address user) external view returns (
        uint256 principal,
        uint256 accruedInterest,
        uint256 lastUpdateTime
    ) {
        DepositInfo memory deposit = deposits[user];
        return (deposit.principal, deposit.accruedInterest, deposit.lastUpdateTime);
    }
    
    /**
     * @dev 接收ETH的回调函数
     */
    receive() external payable {
        // 允许接收ETH
    }
}