## Token Vesting Contract

这是一个基于 OpenZeppelin 的 ERC20 代币归属（Vesting）合约，实现了带有 cliff 期的线性释放机制。

## 功能特性

- **受益人（Beneficiary）**: 指定的代币接收者
- **锁定期（Cliff）**: 12 个月的锁定期，期间无法释放任何代币
- **线性释放**: 从第 13 个月开始，在接下来的 24 个月内线性释放代币
- **总归属期**: 36 个月（12 个月锁定期 + 24 个月线性释放期）
- **可撤销**: 合约部署者可以撤销未归属的代币
- **安全性**: 基于 OpenZeppelin 的安全合约库

## 合约架构

### 主要合约

- `TokenVesting.sol`: 主要的归属合约
- `MockERC20.sol`: 用于测试的 ERC20 代币合约

### 关键参数

- **总代币数量**: 1,000,000 代币
- **Cliff 期**: 365 天（12 个月）
- **线性释放期**: 730 天（24 个月）
- **释放频率**: 可随时调用 `release()` 函数释放已归属的代币

## 主要函数

### `release()`
释放当前已归属但未释放的代币给受益人。

### `revoke()`
仅限合约所有者调用，撤销未归属的代币并返还给所有者。

### `releasableAmount()`
查看当前可释放的代币数量。

### `vestedAmount()`
查看当前已归属的代币总量。

## 部署和使用

### 1. 编译合约

```bash
forge build
```

### 2. 运行测试

```bash
forge test -vv
```

### 3. 部署合约

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export BENEFICIARY_ADDRESS=beneficiary_address

# 部署合约
forge script script/DeployVesting.s.sol --rpc-url <RPC_URL> --broadcast
```

## 测试覆盖

测试文件 `test/TokenVesting.t.sol` 包含了全面的测试用例：

- ✅ 初始状态验证
- ✅ Cliff 期前无法释放代币
- ✅ Cliff 期后的线性释放
- ✅ 月度释放测试
- ✅ 完整归属期测试
- ✅ 撤销功能测试
- ✅ 权限控制测试
- ✅ 多次释放测试
- ✅ 归属计划准确性测试

## 时间模拟测试

使用 Foundry 的 `vm.warp()` 功能进行时间模拟测试，验证：

- 12 个月 cliff 期的正确实现
- 24 个月线性释放的准确性
- 不同时间点的代币归属计算
- 撤销功能在不同时间点的行为

## 安全考虑

1. **基于 OpenZeppelin**: 使用经过审计的 OpenZeppelin 合约库
2. **SafeERC20**: 使用 SafeERC20 进行安全的代币转移
3. **访问控制**: 只有合约所有者可以撤销归属
4. **重入保护**: 合约设计避免了重入攻击
5. **溢出保护**: Solidity 0.8+ 内置溢出保护

## 归属计划示例

假设在 2024 年 1 月 1 日部署合约并转入 1,000,000 代币：

- **2024年1月1日 - 2024年12月31日**: Cliff 期，无法释放任何代币
- **2025年1月1日**: 开始线性释放
- **2025年2月1日**: 可释放约 41,667 代币（1/24）
- **2025年3月1日**: 可释放约 83,333 代币（2/24）
- **2026年12月31日**: 全部 1,000,000 代币可释放

## Foundry 工具链

本项目使用 Foundry 开发工具链：

- **Forge**: 用于编译、测试和部署
- **Cast**: 用于与合约交互
- **Anvil**: 本地测试网络

### 常用命令

```bash
# 编译
forge build

# 测试
forge test

# 格式化代码
forge fmt

# 生成 gas 快照
forge snapshot
```

## 许可证

MIT License
