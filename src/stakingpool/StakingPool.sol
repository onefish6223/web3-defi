// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IStaking.sol";
import "./interface/IToken.sol";
import "./interface/ILendingPool.sol";

/**
 * @title StakingPool
 * @dev 质押池合约，允许用户质押ETH获得KK Token奖励
 * 质押的ETH会存入借贷市场赚取利息
 */
contract StakingPool is IStaking, ReentrancyGuard, Ownable {
    using SafeERC20 for IToken;
    
    // KK Token 合约
    IToken public immutable kkToken;
    
    // 借贷市场合约
    ILendingPool public lendingPool;
    
    // 每个区块产出的 KK Token 数量
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18; // 10 KK Token
    
    // 总质押量
    uint256 public totalStaked;
    
    // 上次更新奖励的区块号
    uint256 public lastRewardBlock;
    
    // 每个质押单位累积的奖励
    uint256 public accRewardPerShare;
    
    // 用户信息
    struct UserInfo {
        uint256 amount;           // 用户质押的ETH数量
        uint256 rewardDebt;      // 奖励债务
        uint256 pendingRewards;  // 待领取的奖励
    }
    
    // 用户信息映射
    mapping(address => UserInfo) public userInfo;
    
    // 事件
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event LendingPoolUpdated(address indexed newLendingPool);
    
    /**
     * @dev 构造函数
     * @param _kkToken KK Token 合约地址
     */
    constructor(address _kkToken) Ownable(msg.sender) {
        require(_kkToken != address(0), "Invalid KK Token address");
        kkToken = IToken(_kkToken);
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev 设置借贷市场合约地址（仅所有者）
     * @param _lendingPool 借贷市场合约地址
     */
    function setLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
        emit LendingPoolUpdated(_lendingPool);
    }
    
    /**
     * @dev 更新奖励池
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 blocksPassed = block.number - lastRewardBlock;
        uint256 reward = blocksPassed * REWARD_PER_BLOCK;
        
        // 铸造奖励代币
        kkToken.mint(address(this), reward);
        
        // 更新每个质押单位的累积奖励
        accRewardPerShare += (reward * 1e12) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev 质押 ETH 到合约
     */
    function stake() external payable override nonReentrant {
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // 计算待领取的奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
            user.pendingRewards += pending;
        }
        
        // 更新用户质押信息
        user.amount += msg.value;
        totalStaked += msg.value;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 如果设置了借贷市场，将ETH存入借贷市场
        if (address(lendingPool) != address(0)) {
            lendingPool.depositETH{value: msg.value}();
        }
        
        emit Staked(msg.sender, msg.value);
    }
    
    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Cannot unstake 0 ETH");
        
        updatePool();
        
        // 计算待领取的奖励
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
        user.pendingRewards += pending;
        
        // 更新用户质押信息
        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 从借贷市场提取ETH（如果有设置）
        if (address(lendingPool) != address(0)) {
            lendingPool.withdrawETH(amount);
        }
        
        // 转账ETH给用户
        payable(msg.sender).transfer(amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external override nonReentrant {
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // 计算总的待领取奖励
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
        uint256 totalReward = user.pendingRewards + pending;
        
        require(totalReward > 0, "No rewards to claim");
        
        // 重置用户奖励信息
        user.pendingRewards = 0;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 转账奖励代币给用户
        kkToken.safeTransfer(msg.sender, totalReward);
        
        emit RewardClaimed(msg.sender, totalReward);
    }
    
    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }
    
    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view override returns (uint256) {
        UserInfo memory user = userInfo[account];
        
        uint256 currentAccRewardPerShare = accRewardPerShare;
        
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * REWARD_PER_BLOCK;
            currentAccRewardPerShare += (reward * 1e12) / totalStaked;
        }
        
        uint256 pending = (user.amount * currentAccRewardPerShare) / 1e12 - user.rewardDebt;
        return user.pendingRewards + pending;
    }
    
    /**
     * @dev 获取借贷市场中的总余额（包含利息）
     * @return 借贷市场余额
     */
    function getLendingBalance() external view returns (uint256) {
        if (address(lendingPool) == address(0)) {
            return 0;
        }
        return lendingPool.getBalance(address(this));
    }
    
    /**
     * @dev 紧急提取函数（仅所有者）
     * 用于紧急情况下提取合约中的ETH
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
    }
    
    /**
     * @dev 接收ETH的回调函数
     */
    receive() external payable {
        // 允许从借贷市场接收ETH
    }
}