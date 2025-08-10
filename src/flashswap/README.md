# 闪电兑换套利系统

这个项目实现了一个完整的闪电兑换套利系统，可以在两个Uniswap V2池子之间进行套利交易。

# 测试日志
mxli@MxdeMacBook-Pro web3-defi % forge test --match-test testExecuteArbitrage -vvvv
[⠊] Compiling...
No files changed, compilation skipped

Ran 1 test for test/FlashSwapArbitrage.t.sol:FlashSwapArbitrageTest
[PASS] testExecuteArbitrage() (gas: 176213)
Logs:
  Initial balance A: 0
  Initial balance B: 0
  Testing arbitrage opportunity...
  Final balance A: 0
  Final balance B: 9844831509977548523

Traces:
  [204513] FlashSwapArbitrageTest::testExecuteArbitrage()
    ├─ [0] VM::startPrank(deployer: [0xaE0bDc4eEAC5E950B67C6819B118761CaAF61946])
    │   └─ ← [Return]
    ├─ [5798] FlashSwapArbitrage::getTokenBalance(MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264]) [staticcall]
    │   ├─ [2560] MyToken::balanceOf(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8]) [staticcall]
    │   │   └─ ← [Return] 0
    │   └─ ← [Return] 0
    ├─ [5798] FlashSwapArbitrage::getTokenBalance(MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]) [staticcall]
    │   ├─ [2560] MyToken::balanceOf(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8]) [staticcall]
    │   │   └─ ← [Return] 0
    │   └─ ← [Return] 0
    ├─ [0] console::log("Initial balance A:", 0) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Initial balance B:", 0) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Testing arbitrage opportunity...") [staticcall]
    │   └─ ← [Stop]
    ├─ [167400] FlashSwapArbitrage::executeArbitrage(MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264], MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5], 10000000000000000000 [1e19], true)
    │   ├─ [2761] UniswapV2Factory::getPair(MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264], MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]) [staticcall]
    │   │   └─ ← [Return] UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb]
    │   ├─ [2761] UniswapV2Factory::getPair(MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264], MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]) [staticcall]
    │   │   └─ ← [Return] UniswapV2Pair: [0x287075153169cf4a30F3f09983f5Be07c8304D02]
    │   ├─ [2448] UniswapV2Pair::token0() [staticcall]
    │   │   └─ ← [Return] MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264]
    │   ├─ [2380] UniswapV2Pair::token1() [staticcall]
    │   │   └─ ← [Return] MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]
    │   ├─ [138624] UniswapV2Pair::swap(10000000000000000000 [1e19], 0, FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264000000000000000000000000ff2bd636b9fc89645c2d336aeade2e4abafe1ea50000000000000000000000000000000000000000000000008ac7230489e800000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000287075153169cf4a30f3f09983f5be07c8304d02000000000000000000000000ae0bdc4eeac5e950b67c6819b118761caaf61946)
    │   │   ├─ [27959] MyToken::transfer(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 10000000000000000000 [1e19])
    │   │   │   ├─ emit Transfer(from: UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb], to: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], value: 10000000000000000000 [1e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ [88609] FlashSwapArbitrage::uniswapV2Call(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 10000000000000000000 [1e19], 0, 0x0000000000000000000000001240fa2a84dd9157a0e76b5cfe98b1d52268b264000000000000000000000000ff2bd636b9fc89645c2d336aeade2e4abafe1ea50000000000000000000000000000000000000000000000008ac7230489e800000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000287075153169cf4a30f3f09983f5be07c8304d02000000000000000000000000ae0bdc4eeac5e950b67c6819b118761caaf61946)
    │   │   │   ├─ [448] UniswapV2Pair::token0() [staticcall]
    │   │   │   │   └─ ← [Return] MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264]
    │   │   │   ├─ [380] UniswapV2Pair::token1() [staticcall]
    │   │   │   │   └─ ← [Return] MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]
    │   │   │   ├─ [761] UniswapV2Factory::getPair(MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264], MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]) [staticcall]
    │   │   │   │   └─ ← [Return] UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb]
    │   │   │   ├─ [8059] MyToken::transfer(UniswapV2Pair: [0x287075153169cf4a30F3f09983f5Be07c8304D02], 10000000000000000000 [1e19])
    │   │   │   │   ├─ emit Transfer(from: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], to: UniswapV2Pair: [0x287075153169cf4a30F3f09983f5Be07c8304D02], value: 10000000000000000000 [1e19])
    │   │   │   │   └─ ← [Return] true
    │   │   │   ├─ [2448] UniswapV2Pair::token0() [staticcall]
    │   │   │   │   └─ ← [Return] MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264]
    │   │   │   ├─ [2380] UniswapV2Pair::token1() [staticcall]
    │   │   │   │   └─ ← [Return] MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]
    │   │   │   ├─ [2525] UniswapV2Pair::getReserves() [staticcall]
    │   │   │   │   └─ ← [Return] 100000000000000000000000 [1e23], 300000000000000000000000 [3e23], 1
    │   │   │   ├─ [47410] UniswapV2Pair::swap(0, 29907018270278453238 [2.99e19], FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x)
    │   │   │   │   ├─ [27959] MyToken::transfer(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 29907018270278453238 [2.99e19])
    │   │   │   │   │   ├─ emit Transfer(from: UniswapV2Pair: [0x287075153169cf4a30F3f09983f5Be07c8304D02], to: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], value: 29907018270278453238 [2.99e19])
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [560] MyToken::balanceOf(UniswapV2Pair: [0x287075153169cf4a30F3f09983f5Be07c8304D02]) [staticcall]
    │   │   │   │   │   └─ ← [Return] 100010000000000000000000 [1e23]
    │   │   │   │   ├─ [560] MyToken::balanceOf(UniswapV2Pair: [0x287075153169cf4a30F3f09983f5Be07c8304D02]) [staticcall]
    │   │   │   │   │   └─ ← [Return] 299970092981729721546762 [2.999e23]
    │   │   │   │   ├─ emit Sync(reserve0: 100010000000000000000000 [1e23], reserve1: 299970092981729721546762 [2.999e23])
    │   │   │   │   ├─ emit Swap(sender: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], amount0In: 10000000000000000000 [1e19], amount1In: 0, amount0Out: 0, amount1Out: 29907018270278453238 [2.99e19], to: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8])
    │   │   │   │   └─ ← [Stop]
    │   │   │   ├─ [448] UniswapV2Pair::token0() [staticcall]
    │   │   │   │   └─ ← [Return] MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264]
    │   │   │   ├─ [380] UniswapV2Pair::token1() [staticcall]
    │   │   │   │   └─ ← [Return] MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]
    │   │   │   ├─ [525] UniswapV2Pair::getReserves() [staticcall]
    │   │   │   │   └─ ← [Return] 100000000000000000000000 [1e23], 200000000000000000000000 [2e23], 1
    │   │   │   ├─ [8059] MyToken::transfer(UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb], 20062186760300904715 [2.006e19])
    │   │   │   │   ├─ emit Transfer(from: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], to: UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb], value: 20062186760300904715 [2.006e19])
    │   │   │   │   └─ ← [Return] true
    │   │   │   ├─ emit ArbitrageExecuted(tokenA: MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264], tokenB: MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5], amountBorrowed: 10000000000000000000 [1e19], profit: 9844831509977548523 [9.844e18])
    │   │   │   └─ ← [Stop]
    │   │   ├─ [560] MyToken::balanceOf(UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb]) [staticcall]
    │   │   │   └─ ← [Return] 99990000000000000000000 [9.999e22]
    │   │   ├─ [560] MyToken::balanceOf(UniswapV2Pair: [0xA7Ff88AE6824E5A05B300cDC82e0a0359F3c18fb]) [staticcall]
    │   │   │   └─ ← [Return] 200020062186760300904715 [2e23]
    │   │   ├─ emit Sync(reserve0: 99990000000000000000000 [9.999e22], reserve1: 200020062186760300904715 [2e23])
    │   │   ├─ emit Swap(sender: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], amount0In: 0, amount1In: 20062186760300904715 [2.006e19], amount0Out: 10000000000000000000 [1e19], amount1Out: 0, to: FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8])
    │   │   └─ ← [Stop]
    │   └─ ← [Stop]
    ├─ [1298] FlashSwapArbitrage::getTokenBalance(MyToken: [0x1240FA2A84dd9157a0e76B5Cfe98B1d52268B264]) [staticcall]
    │   ├─ [560] MyToken::balanceOf(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8]) [staticcall]
    │   │   └─ ← [Return] 0
    │   └─ ← [Return] 0
    ├─ [1298] FlashSwapArbitrage::getTokenBalance(MyToken: [0xfF2Bd636B9Fc89645C2D336aeaDE2E4AbaFe1eA5]) [staticcall]
    │   ├─ [560] MyToken::balanceOf(FlashSwapArbitrage: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8]) [staticcall]
    │   │   └─ ← [Return] 9844831509977548523 [9.844e18]
    │   └─ ← [Return] 9844831509977548523 [9.844e18]
    ├─ [0] console::log("Final balance A:", 0) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Final balance B:", 9844831509977548523 [9.844e18]) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    └─ ← [Stop]

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.71ms (1.00ms CPU time)

Ran 1 test suite in 1.79s (3.71ms CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
mxli@MxdeMacBook-Pro web3-defi % forge test --match-contract FlashSwapArbitrageTest -vv 
[⠊] Compiling...
No files changed, compilation skipped

Ran 7 tests for test/FlashSwapArbitrage.t.sol:FlashSwapArbitrageTest
[PASS] testDeployment() (gas: 15765)
[PASS] testExecuteArbitrage() (gas: 176213)
Logs:
  Initial balance A: 0
  Initial balance B: 0
  Testing arbitrage opportunity...
  Final balance A: 0
  Final balance B: 9844831509977548523

[PASS] testOnlyOwnerCanExecute() (gas: 18078)
[PASS] testPoolPrices() (gas: 19844)
Logs:
  Pool A reserves: 100000000000000000000000 200000000000000000000000
  Pool B reserves: 100000000000000000000000 300000000000000000000000

[PASS] testRevertWhenArbitrageWithIdenticalTokens() (gas: 21157)
[PASS] testRevertWhenArbitrageWithZeroAmount() (gas: 23312)
[PASS] testWithdrawProfit() (gas: 163549)
Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 4.07ms (6.41ms CPU time)

Ran 1 test suite in 189.79ms (4.07ms CPU time): 7 tests passed, 0 failed, 0 skipped (7 total tests)



## 系统组件

### 1. 合约文件

- `MyToken.sol` - 自定义ERC20代币合约
- `FlashSwapArbitrage.sol` - 闪电兑换套利合约

### 2. 部署脚本

- `DeployArbitrageSystem.s.sol` - 完整系统部署脚本
- `DeployLocal.s.sol` - 本地测试部署脚本
- `DeploySepolia.s.sol` - Sepolia测试网部署脚本
- `ExecuteArbitrage.s.sol` - 执行套利操作脚本

### 3. 测试文件

- `FlashSwapArbitrage.t.sol` - 套利合约测试

## 工作原理

1. **价差检测**: 系统检测两个Uniswap V2池子之间的价格差异
2. **闪电借贷**: 从价格较高的池子A借入代币A  A 1 = B 100
3. **套利交易**: 在价格较低的池子B中用代币A兑换代币B A 1 = B 150
4. **偿还借贷**: 用部分代币B在池子A中来偿还借贷 
5. **获取利润**: 剩余的代币就是套利利润

## 部署和使用

### 本地部署

1. 启动本地节点:
```bash
anvil
```

2. 设置环境变量:
```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

3. 部署完整系统:
```bash
forge script script/DeployArbitrageSystem.s.sol --rpc-url http://localhost:8545 --broadcast
```

4. 执行套利:
```bash
# 设置合约地址环境变量
export ARBITRAGE_CONTRACT=<套利合约地址>
export TOKEN_A=<代币A地址>
export TOKEN_B=<代币B地址>
export FACTORY_A=<工厂A地址>
export FACTORY_B=<工厂B地址>

# 执行套利
forge script script/ExecuteArbitrage.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Sepolia测试网部署

1. 设置环境变量:
```bash
export PRIVATE_KEY=<你的私钥>
export SEPOLIA_RPC_URL=<Sepolia RPC URL>
```

2. 部署代币:
```bash
forge script script/DeploySepolia.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## 测试

运行所有测试:
```bash
forge test
```

运行特定测试:
```bash
forge test --match-contract FlashSwapArbitrageTest
```

查看测试覆盖率:
```bash
forge coverage
```

## 安全注意事项

1. **滑点保护**: 合约包含滑点保护机制
2. **重入攻击防护**: 使用ReentrancyGuard防止重入攻击
3. **权限控制**: 只有合约所有者可以执行套利操作
4. **价格验证**: 在执行套利前验证价格差异

## 套利策略

### 基本策略

当池子A中的价格高于池子B时:
1. 从池子A借入代币A
2. 在池子B中用代币A兑换代币B
3. 用部分代币B在池子B中换回代币A偿还借贷
4. 剩余代币B为利润

### 高级策略

- **多池套利**: 可以扩展到多个池子之间的套利
- **跨链套利**: 在不同区块链之间进行套利
- **MEV保护**: 实现MEV保护机制避免被抢跑

## 风险提示

1. **无常损失**: 流动性提供者面临无常损失风险
2. **Gas费用**: 高Gas费用可能吞噬套利利润
3. **滑点风险**: 大额交易可能面临较大滑点
4. **智能合约风险**: 合约可能存在未知漏洞
5. **市场风险**: 价格快速变化可能导致套利失败

## 优化建议

1. **Gas优化**: 优化合约代码减少Gas消耗
2. **MEV保护**: 实现commit-reveal机制
3. **动态参数**: 根据市场条件动态调整参数
4. **监控系统**: 建立实时监控和告警系统

## 许可证

MIT License