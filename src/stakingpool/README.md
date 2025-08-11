# StakingPool 质押池系统

## 概述

StakingPool 是一个去中心化的质押系统，允许用户质押 ETH 来获得 KK Token 奖励。系统集成了借贷市场功能，质押的 ETH 会自动存入借贷市场赚取额外利息。

## 核心特性

### 1. 质押挖矿
- 用户可以质押 ETH 到合约中
- 每个区块产出 10 个 KK Token
- 奖励按照质押比例公平分配（参考 SushiSwap 的分配机制）
- 支持随时质押和解除质押

### 2. 借贷市场集成
- 质押的 ETH 自动存入借贷市场（如 Aave、Compound）
- 赚取额外的借贷利息收益
- 提取时自动从借贷市场赎回 ETH

### 3. 灵活的奖励机制
- 实时计算用户奖励
- 支持随时领取 KK Token 奖励
- 奖励计算基于区块高度和质押比例

## 合约架构

### 核心合约

1. **KKToken.sol** - KK Token 合约
   - 标准 ERC20 代币
   - 支持铸造功能（仅质押池可调用）

2. **StakingPool.sol** - 质押池主合约
   - 实现 IStaking 接口
   - 管理用户质押和奖励分配
   - 集成借贷市场功能

3. **MockLendingPool.sol** - 模拟借贷市场
   - 演示借贷集成功能
   - 提供 5% 年化收益率
   - 实际部署时应替换为真实的借贷协议

### 接口定义

1. **IStaking.sol** - 质押接口
   ```solidity
   function stake() payable external;           // 质押 ETH
   function unstake(uint256 amount) external;   // 解除质押
   function claim() external;                   // 领取奖励
   function balanceOf(address account) external view returns (uint256);
   function earned(address account) external view returns (uint256);
   ```

2. **IToken.sol** - KK Token 接口
   ```solidity
   function mint(address to, uint256 amount) external;
   ```

3. **ILendingPool.sol** - 借贷市场接口
   ```solidity
   function depositETH() external payable;
   function withdrawETH(uint256 amount) external;
   function getBalance(address user) external view returns (uint256);
   ```

## 奖励分配机制

### 算法原理

系统采用类似 SushiSwap 的奖励分配算法：

1. **累积奖励计算**：
   ```
   accRewardPerShare += (blockReward * 1e12) / totalStaked
   ```

2. **用户奖励计算**：
   ```
   userReward = (userStake * accRewardPerShare) / 1e12 - userRewardDebt
   ```

3. **奖励债务更新**：
   ```
   userRewardDebt = (userStake * accRewardPerShare) / 1e12
   ```

### 分配示例

假设：
- 每区块产出 10 KK Token
- 用户 A 质押 10 ETH，用户 B 质押 30 ETH
- 总质押量 40 ETH

在第 N 个区块：
- 用户 A 获得：10 * (10/40) = 2.5 KK Token
- 用户 B 获得：10 * (30/40) = 7.5 KK Token

## 借贷市场集成

### 集成流程

1. **质押时**：
   ```solidity
   // 用户质押 ETH
   stakingPool.stake{value: amount}();
   
   // 系统自动将 ETH 存入借贷市场
   lendingPool.depositETH{value: amount}();
   ```

2. **解除质押时**：
   ```solidity
   // 从借贷市场提取 ETH
   lendingPool.withdrawETH(amount);
   
   // 返还给用户
   payable(user).transfer(amount);
   ```

### 支持的借贷协议

- **Aave V3**：主流借贷协议，支持多种资产
- **Compound V3**：老牌借贷协议，稳定可靠
- **自定义协议**：可以集成任何实现 ILendingPool 接口的协议

## 部署和使用

### 部署步骤

1. **设置环境变量**：
   ```bash
   export PRIVATE_KEY=your_private_key
   ```

2. **部署合约**：
   ```bash
   forge script script/DeployStakingPool.s.sol --rpc-url <RPC_URL> --broadcast
   ```

3. **验证部署**：
   ```bash
   forge test --match-contract StakingPoolTest
   ```

### 用户操作

1. **质押 ETH**：
   ```solidity
   stakingPool.stake{value: 1 ether}();
   ```

2. **查看奖励**：
   ```solidity
   uint256 rewards = stakingPool.earned(userAddress);
   ```

3. **领取奖励**：
   ```solidity
   stakingPool.claim();
   ```

4. **解除质押**：
   ```solidity
   stakingPool.unstake(0.5 ether);
   ```

## 安全特性

### 重入攻击防护
- 使用 OpenZeppelin 的 ReentrancyGuard
- 所有外部调用都有重入保护

### 权限控制
- KK Token 只能由质押池铸造
- 借贷市场地址只能由合约所有者设置
- 紧急提取功能仅限所有者

### 数值安全
- 使用 SafeMath 防止溢出
- 精度处理使用 1e12 倍数
- 边界条件检查

## 测试覆盖

测试文件 `StakingPool.t.sol` 包含以下测试用例：

- ✅ 基本质押功能
- ✅ 多用户质押
- ✅ 奖励计算
- ✅ 奖励领取
- ✅ 解除质押
- ✅ 比例分配
- ✅ 借贷市场集成
- ✅ 边界条件测试

运行测试：
```bash
forge test --match-contract StakingPoolTest -vvv
```

## 升级和扩展

### 可能的改进

1. **多资产支持**：支持质押多种 ERC20 代币
2. **动态奖励率**：根据市场条件调整奖励率
3. **治理功能**：添加 DAO 治理机制
4. **NFT 集成**：支持 NFT 质押获得额外奖励
5. **跨链支持**：扩展到多个区块链网络

### 集成真实借贷协议

替换 MockLendingPool 为真实协议：

```solidity
// Aave V3 集成示例
interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external;
}

// 在 StakingPool 中集成
function stake() external payable {
    // ... 质押逻辑
    
    // 存入 Aave
    IWETH(weth).deposit{value: msg.value}();
    IERC20(weth).approve(address(aavePool), msg.value);
    aavePool.supply(weth, msg.value, address(this), 0);
}
```

## 许可证

GPL-3.0 License