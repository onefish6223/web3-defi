# UniswapV2 本地部署指南

本指南将帮助您在本地 Anvil 网络上部署 UniswapV2 合约。

## 前置要求

1. 安装 [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. 确保项目依赖已安装：`forge install`

## 快速开始

### 1. 启动本地网络

在一个终端窗口中启动 Anvil：

```bash
anvil
```

这将启动一个本地以太坊网络，默认运行在 `http://127.0.0.1:8545`

### 2. 配置环境变量

复制环境变量示例文件：

```bash
cp .env.example .env
```

默认配置使用 Anvil 的第一个测试账户，无需修改。

### 3. 部署合约

在另一个终端窗口中运行部署脚本：

```bash
forge script script/DeployUniswapV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## 部署内容

部署脚本将创建以下合约：

### 核心合约
- **UniswapV2Factory**: 工厂合约，用于创建交易对
- **UniswapV2Router02**: 路由器合约，提供用户友好的交易接口

### 测试代币
- **WETH**: 包装以太币
- **TokenA**: 测试代币 A
- **TokenB**: 测试代币 B  
- **USDC**: 模拟 USDC 稳定币

### 交易对
脚本会自动创建以下交易对并添加初始流动性（每个池 10,000 代币）：
- TokenA/TokenB
- TokenA/USDC
- WETH/USDC

## 部署后操作

部署完成后，您可以：

1. **查看部署信息**: 合约地址将保存在 `./deployments/anvil-deployment.md`
2. **与合约交互**: 使用 Router 地址进行代币交换、添加/移除流动性等操作
3. **运行测试**: `forge test` 验证所有功能正常工作

## 常用操作示例

### 代币交换

```solidity
// 使用 Router 进行代币交换
router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    to,
    deadline
);
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

## 故障排除

### 常见问题

1. **部署失败**: 确保 Anvil 正在运行且 RPC URL 正确
2. **权限错误**: 检查私钥是否正确配置
3. **Gas 不足**: Anvil 默认提供充足的 ETH，通常不会遇到此问题

### 重新部署

如需重新部署，重启 Anvil 即可获得干净的环境：

```bash
# 停止当前 Anvil (Ctrl+C)
# 重新启动
anvil
```

## 网络信息

- **Chain ID**: 31337
- **RPC URL**: http://127.0.0.1:8545
- **默认账户**: 10 个预充值账户，每个有 10,000 ETH
- **默认私钥**: 见 `.env.example` 文件

## 安全提醒

⚠️ **重要**: 示例私钥仅用于本地开发，切勿在主网或测试网使用！