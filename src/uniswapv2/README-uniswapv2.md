# UniswapV2 项目文档

## 项目概述

本项目是 UniswapV2 去中心化交易所的完整实现，基于 Solidity ^0.8.0 开发。UniswapV2 是一个自动做市商（AMM）协议，允许用户在没有传统订单簿的情况下进行代币交换和提供流动性。

## 项目结构

```
src/uniswapv2/
├── UniswapV2Factory.sol      # 工厂合约 - 创建和管理交易对
├── UniswapV2Pair.sol         # 交易对合约 - 核心AMM逻辑
├── UniswapV2Router02.sol     # 路由器合约 - 用户交互接口
├── UniswapV2ERC20.sol        # ERC20实现 - 流动性代币基础
├── interfaces/               # 接口定义
│   ├── IUniswapV2Factory.sol
│   ├── IUniswapV2Pair.sol
│   ├── IUniswapV2Router01.sol
│   ├── IUniswapV2Router02.sol
│   ├── IUniswapV2ERC20.sol
│   ├── IUniswapV2Callee.sol
│   └── IWETH.sol
└── libraries/                # 工具库
    ├── UniswapV2Library.sol  # 核心计算函数
    ├── Math.sol              # 数学运算
    ├── SafeMath.sol          # 安全数学运算
    ├── TransferHelper.sol    # 安全转账
    └── UQ112x112.sol         # 定点数运算
```

## 核心合约详解

### 1. UniswapV2Factory.sol

**功能**: 工厂合约负责创建和管理所有的交易对合约

**主要特性**:
- 创建新的交易对合约
- 管理协议手续费设置
- 维护所有交易对的注册表
- 使用 CREATE2 确保交易对地址的确定性

**关键函数**:
- `createPair(address tokenA, address tokenB)`: 创建新的交易对
- `getPair(address tokenA, address tokenB)`: 获取交易对地址
- `allPairsLength()`: 获取交易对总数
- `setFeeTo(address)`: 设置协议手续费接收地址

### 2. UniswapV2Pair.sol

**功能**: 交易对合约实现了两种代币之间的自动做市商功能

**主要特性**:
- 恒定乘积做市商模型 (x * y = k)
- 流动性提供和移除
- 代币交换功能
- 价格预言机（累积价格）
- 协议手续费机制
- 闪电贷功能

**关键函数**:
- `mint(address to)`: 铸造流动性代币
- `burn(address to)`: 销毁流动性代币
- `swap(uint amount0Out, uint amount1Out, address to, bytes calldata data)`: 执行代币交换
- `getReserves()`: 获取储备量信息
- `sync()`: 同步储备量

**重要常量**:
- `MINIMUM_LIQUIDITY = 10**3`: 最小流动性，防止除零错误

### 3. UniswapV2Router02.sol

**功能**: 路由器合约提供了与 UniswapV2 交互的高级接口

**主要特性**:
- 简化的流动性管理接口
- 多跳代币交换
- ETH 和 ERC20 代币的统一处理
- 滑点保护
- 截止时间保护

**关键函数**:
- `addLiquidity()`: 添加 ERC20 代币流动性
- `addLiquidityETH()`: 添加 ETH 流动性
- `removeLiquidity()`: 移除流动性
- `swapExactTokensForTokens()`: 精确输入交换
- `swapTokensForExactTokens()`: 精确输出交换
- `getAmountsOut()`: 计算输出数量
- `getAmountsIn()`: 计算输入数量

### 4. UniswapV2ERC20.sol

**功能**: 实现了标准 ERC20 功能的流动性代币

**主要特性**:
- 标准 ERC20 代币功能
- EIP-2612 permit 功能（无 gas 授权）
- 用作流动性证明代币（LP Token）

**代币信息**:
- 名称: "Uniswap V2"
- 符号: "UNI-V2"
- 精度: 18

## 工具库说明

### UniswapV2Library.sol

提供路由器所需的各种计算函数：
- `sortTokens()`: 按字典序排序代币地址
- `pairFor()`: 计算交易对地址
- `getReserves()`: 获取储备量
- `quote()`: 根据储备量计算等价数量
- `getAmountOut()`: 计算输出数量
- `getAmountIn()`: 计算输入数量
- `getAmountsOut()`: 计算多跳交换的输出数量
- `getAmountsIn()`: 计算多跳交换的输入数量

### 其他工具库

- **Math.sol**: 提供数学运算函数，如平方根计算
- **SafeMath.sol**: 安全的数学运算，防止溢出
- **TransferHelper.sol**: 安全的代币转账函数
- **UQ112x112.sol**: 定点数运算，用于价格计算

## 核心机制

### 1. 恒定乘积做市商模型

UniswapV2 使用恒定乘积公式：`x * y = k`
- x, y 分别是两种代币的储备量
- k 是常数，只有在添加或移除流动性时才会改变
- 交换时保持 k 不变，价格由储备量比例决定

### 2. 手续费机制

- **交易手续费**: 每笔交换收取 0.3% 的手续费
- **协议手续费**: 可选的协议层面手续费（默认关闭）
- 手续费直接添加到流动性池中，使 LP 代币升值

### 3. 价格预言机

- 维护累积价格，可用于计算时间加权平均价格（TWAP）
- 每个区块第一笔交易时更新累积价格
- 提供抗操纵的价格数据源

### 4. 闪电贷

- 允许在单笔交易中借出代币并归还
- 必须在交易结束前归还借款加手续费
- 可用于套利、清算等高级策略

## 安全特性

1. **重入保护**: 使用重入锁防止重入攻击
2. **溢出保护**: 使用 SafeMath 防止整数溢出
3. **最小流动性**: 防止除零错误和价格操纵
4. **截止时间检查**: 防止交易在过期后执行
5. **滑点保护**: 用户可设置最小输出或最大输入

## 使用示例

### 创建交易对

```solidity
// 通过工厂合约创建新的交易对
address pair = factory.createPair(tokenA, tokenB);
```

### 添加流动性

```solidity
// 添加流动性
router.addLiquidity(
    tokenA,
    tokenB,
    amountADesired,
    amountBDesired,
    amountAMin,
    amountBMin,
    to,
    deadline
);
```

### 代币交换

```solidity
// 精确输入交换
address[] memory path = new address[](2);
path[0] = tokenA;
path[1] = tokenB;

router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    to,
    deadline
);
```

## 部署说明

1. 首先部署工厂合约
2. 部署路由器合约，传入工厂和 WETH 地址
3. 根据需要创建交易对
4. 用户通过路由器合约进行交互

## 注意事项

1. **滑点**: 大额交易可能面临较大滑点
2. **无常损失**: 流动性提供者面临无常损失风险
3. **MEV**: 交易可能受到 MEV（最大可提取价值）攻击
4. **合约风险**: 智能合约存在潜在漏洞风险

## 相关资源

- [Uniswap V2 白皮书](https://uniswap.org/whitepaper.pdf)
- [Uniswap V2 核心代码](https://github.com/Uniswap/v2-core)
- [Uniswap V2 外围代码](https://github.com/Uniswap/v2-periphery)

---

本文档提供了 UniswapV2 项目的完整技术概览。如需了解更多实现细节，请参考源代码和相关测试文件。