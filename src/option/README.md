# 看涨期权 Token (Call Option)

## 概述

这是一个基于 ERC20 标准的看涨期权 Token 合约，允许用户购买和行权 ETH 看涨期权。期权持有者可以在到期日以预定的行权价格购买标的资产（ETH）。

## 主要功能

### 1. 期权发行（项目方角色）
- 项目方可以通过存入 ETH 来发行期权 Token
- 发行比例为 1:1（1 ETH = 1 期权 Token）
- 只能在到期日之前发行

### 2. 期权交易
- 期权 Token 遵循 ERC20 标准，可以自由转账和交易
- 可以与 USDT 创建交易对，模拟用户购买期权
- 支持在 DEX 上进行流动性挖矿

### 3. 期权行权（用户角色）
- 用户可以在到期日当天行权
- 需要支付 USDT（按行权价格计算）
- 获得对应数量的 ETH
- 期权 Token 被销毁

### 4. 过期销毁（项目方角色）
- 行权期结束后，项目方可以销毁所有剩余期权
- 赎回未被行权的 ETH
- 收取行权产生的 USDT

## 合约参数

- **行权价格 (Strike Price)**: 以 USDT 计价的行权价格
- **到期日期 (Expiration Date)**: 期权到期的时间戳
- **标的资产 (Underlying Asset)**: ETH（address(0)）
- **计价货币**: USDT（6位小数）
- **行权期**: 到期日当天（24小时）

## 使用流程

### 项目方操作

1. **部署合约**
```solidity
CallOption callOption = new CallOption(
    "ETH Call Option Dec 2024",  // 期权名称
    "ETH-CALL-DEC24",            // 期权符号
    3000e6,                       // 行权价格 (3000 USDT)
    block.timestamp + 30 days,    // 到期日期
    2500e6,                       // 当前ETH价格
    address(0),                   // ETH地址
    usdtTokenAddress              // USDT地址
);
```

2. **发行期权**
```solidity
// 存入 10 ETH，发行 10 个期权 Token
callOption.issueOptions{value: 10 ether}();
```

3. **转移期权给用户或市场**
```solidity
// 转移 5 个期权 Token 给用户
callOption.transfer(userAddress, 5 ether);
```

4. **过期销毁**
```solidity
// 在行权期结束后执行
callOption.expireOptions();
```

### 用户操作

1. **购买期权**
```solidity
// 从项目方或市场购买期权 Token
// 可以通过 DEX 交易对购买
```

2. **行权**
```solidity
// 授权 USDT
usdtToken.approve(address(callOption), usdtAmount);

// 行权 2 个期权 Token
callOption.exerciseOption(2 ether);
```

## 安全特性

- **重入攻击防护**: 使用 ReentrancyGuard
- **权限控制**: 使用 Ownable 控制关键操作
- **时间锁**: 严格的时间窗口控制
- **余额检查**: 完整的余额和授权检查
- **事件记录**: 完整的事件日志

## 事件

```solidity
event OptionIssued(address indexed issuer, uint256 underlyingAmount, uint256 optionTokens);
event OptionExercised(address indexed exerciser, uint256 optionTokens, uint256 underlyingReceived);
event OptionExpired(uint256 underlyingRedeemed);
event UnderlyingPriceUpdated(uint256 newPrice);
```

## 查询函数

- `getOptionDetails()`: 获取期权详细信息
- `canExercise()`: 检查是否可以行权
- `calculateExerciseCost(uint256 optionAmount)`: 计算行权成本

## 测试

运行测试：
```bash
forge test --match-contract CallOptionTest -v
```

## 部署

使用部署脚本：
```bash
forge script script/DeployCallOption.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## 注意事项

1. **精度处理**: ETH 使用 18 位小数，USDT 使用 6 位小数
2. **时间窗口**: 行权期仅为到期日当天 24 小时
3. **Gas 优化**: 合约已优化 Gas 使用
4. **测试网部署**: 建议先在测试网部署和测试

## 风险提示

- 期权具有时间价值，过期后将失去价值
- 行权需要支付相应的 USDT
- 智能合约风险，请在使用前进行充分测试
- 价格波动风险，请谨慎投资

## 许可证

MIT License