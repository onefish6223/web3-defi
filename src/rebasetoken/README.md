# 通缩型 Rebase Token (DeflationaryRebaseToken)

## 概述

这是一个实现通缩机制的 ERC20 代币合约，通过 rebase 机制实现每年 1% 的通缩率。该合约展示了 rebase 型代币的核心实现原理。

## 核心特性

### 1. 初始参数
- **起始发行量**: 1 亿代币 (100,000,000 tokens)
- **通缩率**: 每年 1% (即保留 99%)
- **代币名称**: Deflationary Rebase Token (DRT)
- **精度**: 18 位小数

### 2. Rebase 机制

#### 工作原理
- 合约维护两套余额系统：
  - `_rawBalances`: 用户的原始余额（不受 rebase 影响）
  - `balanceOf()`: 显示余额（受 rebase 倍数影响）
- 通过 `_rebaseMultiplier` 倍数来调整显示余额
- 每次 rebase 后，倍数乘以 0.99，实现 1% 的通缩

#### 关键公式
```solidity
显示余额 = 原始余额 × rebase倍数 / 1e18
通缩后倍数 = 当前倍数 × 99 / 100
```

### 3. 主要功能

#### Rebase 操作
- `rebase()`: 每年可调用一次，执行通缩
- `forceRebase()`: 管理员强制执行 rebase（用于测试）
- `canRebase()`: 检查是否可以执行 rebase
- `timeUntilNextRebase()`: 获取距离下次 rebase 的时间

#### 余额查询
- `balanceOf(address)`: 获取通缩后的余额
- `rawBalanceOf(address)`: 获取原始余额
- `getRebaseMultiplier()`: 获取当前 rebase 倍数

#### 标准 ERC20 功能
- `transfer()`: 转账
- `transferFrom()`: 授权转账
- `mint()`: 铸造（仅管理员）
- `burn()`: 销毁

## 使用示例

### 部署合约
```solidity
DeflationaryRebaseToken token = new DeflationaryRebaseToken();
```

### 执行 Rebase
```solidity
// 检查是否可以 rebase
if (token.canRebase()) {
    token.rebase();
}

// 或者管理员强制 rebase
token.forceRebase();
```

### 查询余额
```solidity
// 获取通缩后的余额
uint256 balance = token.balanceOf(user);

// 获取原始余额
uint256 rawBalance = token.rawBalanceOf(user);

// 获取当前倍数
uint256 multiplier = token.getRebaseMultiplier();
```

## 通缩效果示例

假设用户持有 1000 个代币：

| 年份 | Rebase倍数 | 显示余额 | 通缩率 |
|------|------------|----------|--------|
| 0    | 1.000      | 1000     | 0%     |
| 1    | 0.990      | 990      | 1%     |
| 2    | 0.980      | 980.1    | 1.99%  |
| 3    | 0.970      | 970.3    | 2.97%  |
| 10   | 0.904      | 904.4    | 9.56%  |

## 测试覆盖

测试文件 `DeflationaryRebaseToken.t.sol` 包含以下测试用例：

1. **基础功能测试**
   - 初始状态验证
   - 转账功能
   - 铸造和销毁

2. **Rebase 机制测试**
   - 时间限制检查
   - 单次 rebase 效果
   - 多次 rebase 累积效果
   - 长期通缩效果（10年）

3. **余额正确性测试**
   - Rebase 后余额显示
   - 比例保持不变
   - 转账后余额计算

## 运行测试

```bash
# 运行所有测试
forge test --match-contract DeflationaryRebaseTokenTest -vv

# 运行特定测试
forge test --match-test testRebaseAfterOneYear -vv
```

## 安全考虑

1. **时间锁定**: Rebase 操作有 1 年的时间间隔限制
2. **权限控制**: 只有合约所有者可以执行 `forceRebase` 和 `mint`
3. **精度处理**: 使用 1e18 精度避免小数计算问题
4. **溢出保护**: 使用 Solidity 0.8+ 的内置溢出检查

## 实际应用场景

这种通缩型 rebase token 可以用于：

1. **通缩经济模型**: 通过减少供应量来维持代币价值
2. **奖励分配**: 长期持有者受益于供应量减少
3. **实验性 DeFi 协议**: 探索新的代币经济学模型
4. **学习和研究**: 理解 rebase 机制的实现原理

## 注意事项

1. **精度损失**: 多次 rebase 可能导致微小的精度损失
2. **兼容性**: 某些 DeFi 协议可能不兼容 rebase 代币
3. **用户体验**: 用户需要理解余额会自动减少的机制
4. **税务影响**: 在某些司法管辖区，rebase 可能有税务影响

## 总结

这个实现展示了如何通过 rebase 机制创建一个通缩型代币。核心思想是维护原始余额不变，通过调整显示倍数来实现通缩效果。这种设计保证了用户持有比例的相对稳定，同时实现了总供应量的定期减少。