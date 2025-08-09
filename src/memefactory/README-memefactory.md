# Meme代币发射平台 (Meme Token Launch Platform)

一个简洁高效的去中心化Meme代币发射平台，支持代币创建、铸造和流动性管理。

# 测试结果
mxli@MxdeMacBook-Pro web3-defi % forge test --match-contract MemeFactoryTest -v         
[⠊] Compiling...
[⠢] Compiling 2 files with Solc 0.8.29
[⠆] Solc 0.8.29 finished in 1.16s
Compiler run successful!

Ran 8 tests for test/MemeFactory.t.sol:MemeFactoryTest
[PASS] testBuyMeme() (gas: 2726724)
[PASS] testBuyMemeNoPair() (gas: 421641)
[PASS] testBuyMemeNonExistentToken() (gas: 25623)
[PASS] testDeployMeme() (gas: 400204)
[PASS] testGetTokenPrice() (gas: 2711750)
[PASS] testMintMemeAndAddLiquidity1() (gas: 2725026)
[PASS] testMintMemeAndAddLiquidityInsufficientPayment() (gas: 412299)
[PASS] testMintMemeAndAddLiquidityNonExistentToken() (gas: 25602)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 6.93ms (4.50ms CPU time)

## 🚀 功能特性

### 核心功能
- **一键创建Meme代币**: 使用最小代理模式高效创建代币
- **按需铸造**: 用户支付ETH按固定价格铸造代币
- **流动性管理**: 集成Uniswap V2流动性添加功能
- **市场交易**: 当Uniswap价格优于起始价格时支持购买
- **价格查询**: 实时获取代币市场价格和起始价格对比
- **平台费用**: 5%平台费用，95%归代币创建者

### 安全特性
- **所有权管理**: 基于OpenZeppelin的Ownable
- **重入攻击保护**: ReentrancyGuard保护
- **滑点保护**: 流动性添加和交易的滑点保护
- **紧急功能**: 紧急提取功能

## 📁 合约架构

```
src/memefactory/
├── MemeToken.sol          # Meme代币合约模板
├── MemeFactory.sol        # 工厂合约，负责创建和管理代币
└── README-memefactory.md  # 项目文档
```

## 🔧 合约详解

### MemeToken.sol
Meme代币合约模板，使用最小代理模式部署，包含以下功能：

**基础功能**
- 标准ERC20代币实现
- 可配置的代币名称、符号和总供应量
- 固定的每次铸造数量和价格
- 按需铸造机制

**铸造控制**
- 只有工厂合约可以铸造代币
- 总供应量限制保护
- 铸造进度跟踪
- 剩余供应量查询

**初始化机制**
- 支持代理合约初始化
- 防止重复初始化
- 创建者和工厂地址绑定

### MemeFactory.sol
工厂合约，负责创建和管理Meme代币：

**代币创建**
- 使用最小代理模式创建代币
- 可配置代币参数（符号、总量、每次铸造量、价格）
- 代币信息存储和管理

**铸造功能**
- 用户支付ETH铸造代币
- 5%平台费用，95%归创建者
- 支持铸造并添加流动性
- 自动退还多余ETH

**流动性管理**
- 集成Uniswap V2路由器
- 自动添加流动性功能
- 滑点保护（5%）
- 流动性添加失败保护

**市场交易**
- 当Uniswap价格优于起始价格时支持购买
- 价格验证和流动性检查
- 通过Uniswap进行代币交换

**查询功能**
- 代币信息查询
- 价格对比查询
- 分页获取代币列表
- 代币存在性验证

## 🛠 部署指南

### 1. 环境准备
```bash
# 安装依赖
forge install

# 编译合约
forge build

# 运行测试
forge test
```

### 2. 部署合约
```bash
# 设置环境变量
export PRIVATE_KEY="your_private_key"
export RPC_URL="your_rpc_url"

# 部署MemeFactory合约（需要Uniswap V2路由器地址）
forge create src/memefactory/MemeFactory.sol:MemeFactory \
  --constructor-args "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. 部署要求
部署前需要确保：
- 网络上已部署Uniswap V2路由器
- 部署账户有足够的ETH支付gas费用
- 合约将自动部署MemeToken模板合约

## 📖 使用示例

### 创建Meme代币
```solidity
// 创建代币
address tokenAddress = memeFactory.deployMeme(
    "MEME",             // 代币符号
    1000000 * 10**18,   // 总供应量
    10000 * 10**18,     // 每次铸造数量
    0.001 ether         // 每个代币价格
);
```

### 铸造代币
```solidity
// 用户支付ETH铸造代币
memeFactory.mintMeme{value: 10 ether}(tokenAddress);
```

### 铸造并添加流动性
```solidity
// 铸造代币并添加流动性
memeFactory.mintMemeAndAddLiquidity{value: 15 ether}(
    tokenAddress,       // 代币地址
    5 ether,           // 用于流动性的ETH数量
    block.timestamp + 300  // 截止时间
);
```

### 购买代币（当价格优于起始价格时）
```solidity
// 通过Uniswap购买代币
memeFactory.buyMeme{value: 1 ether}(
    tokenAddress,       // 代币地址
    0,                 // 最小输出代币数量
    block.timestamp + 300  // 截止时间
);
```

## 🔍 查询功能

### 获取代币信息
```solidity
// 检查代币是否存在
bool exists = memeFactory.isMemeToken(tokenAddress);

// 获取代币详细信息
MemeFactory.MemeInfo memory info = memeFactory.getMemeInfo(tokenAddress);
// info包含：symbol, totalSupply, perMint, price, creator, exists

// 获取所有代币数量
uint256 totalCount = memeFactory.getAllMemeTokensCount();

// 分页获取代币地址
address[] memory tokens = memeFactory.getMemeTokens(0, 9); // 获取前10个代币
```

### 价格信息
```solidity
// 获取代币价格信息
(uint256 currentPrice, uint256 initialPrice, bool isPriceBetter) = 
    memeFactory.getTokenPrice(tokenAddress);
// currentPrice: 当前市场价格
// initialPrice: 起始价格
// isPriceBetter: 当前价格是否优于起始价格
```

### 代币合约查询
```solidity
// 获取剩余可铸造数量
uint256 remaining = memeToken.remainingSupply();

// 检查是否还可以铸造
bool canMint = memeToken.canMint();

// 获取已铸造总量
uint256 minted = memeToken.totalMinted();
```

## ⚠️ 安全注意事项

1. **私钥安全**: 妥善保管部署私钥，建议使用硬件钱包
2. **合约验证**: 部署后及时验证合约源码
3. **权限管理**: 合理设置合约所有者权限，避免滥用
4. **价格设置**: 谨慎设置代币价格和铸造参数
5. **流动性风险**: 添加流动性前确保代币参数正确
6. **滑点保护**: 交易时设置合理的滑点保护参数
7. **市场风险**: 理解代币价格波动风险

## 🧪 测试

运行完整测试套件：
```bash
# 运行所有测试
forge test

# 运行MemeFactory相关测试
forge test --match-contract MemeFactoryTest

# 运行特定测试
forge test --match-test testBuyMeme

# 查看测试覆盖率
forge coverage
```

## 📊 主要事件

合约会发出以下事件用于监听：

```solidity
// 代币部署事件
event MemeDeployed(
    address indexed tokenAddress,
    address indexed creator,
    string symbol,
    uint256 totalSupply,
    uint256 perMint,
    uint256 price
);

// 代币铸造事件
event MemeMinted(
    address indexed tokenAddress,
    address indexed minter,
    uint256 amount,
    uint256 payment,
    uint256 platformFee,
    uint256 creatorFee
);

// 流动性添加事件
event LiquidityAdded(
    address indexed tokenAddress,
    address indexed user,
    uint256 amountToken,
    uint256 amountETH,
    uint256 liquidity
);

// 代币购买事件
event MemeBought(
    address indexed tokenAddress,
    address indexed buyer,
    uint256 amountETH,
    uint256 amountTokens
);
```

## 📄 许可证

MIT License - 详见 [LICENSE](../../LICENSE) 文件

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

---

**免责声明**: 本项目仅供学习和研究使用，使用前请充分了解相关风险。在主网部署前，请进行充分的测试和审计。代币投资存在风险，请谨慎参与。