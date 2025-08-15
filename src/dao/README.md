# DAO 治理系统

这是一个完整的去中心化自治组织(DAO)治理系统，包含可投票的代币、银行资金管理和治理合约。

## 系统架构

### 1. VotingToken.sol - 可投票代币合约
- 基于 ERC20 标准的治理代币
- 支持投票权委托功能
- 记录历史投票权快照
- 实现检查点机制，确保投票权的准确性

**主要功能：**
- `delegate(address delegatee)`: 委托投票权
- `getVotes(address account)`: 获取当前投票权
- `getPastVotes(address account, uint256 blockNumber)`: 获取历史投票权

### 2. Bank.sol - 银行资金管理合约
- 管理 ETH 和 ERC20 代币资金
- 只有管理员（治理合约）可以提取资金
- 支持批量操作和紧急提取

**主要功能：**
- `depositEther()`: 存入 ETH
- `depositToken(address token, uint256 amount)`: 存入 ERC20 代币
- `withdraw(address token, address to, uint256 amount)`: 提取资金（仅管理员）
- `emergencyWithdraw(address token, address to)`: 紧急提取所有资金

### 3. Gov.sol - 治理合约
- 管理提案的创建、投票和执行
- 作为 Bank 合约的管理员
- 实现时间锁机制确保安全性

**主要功能：**
- `propose()`: 创建提案
- `castVote()`: 投票
- `queue()`: 将通过的提案加入执行队列
- `execute()`: 执行提案

## 治理流程

### 1. 提案创建
```solidity
// 创建提案需要满足最小代币持有量要求
address[] memory targets = new address[](1);
uint256[] memory values = new uint256[](1);
bytes[] memory calldatas = new bytes[](1);

targets[0] = address(bank);
values[0] = 0;
calldatas[0] = abi.encodeWithSignature(
    "withdraw(address,address,uint256)",
    tokenAddress,
    recipient,
    amount
);

uint256 proposalId = gov.propose(
    targets,
    values,
    calldatas,
    "提案描述"
);
```

### 2. 投票过程
```solidity
// 等待投票延迟期结束后开始投票
// 0 = 反对, 1 = 支持, 2 = 弃权
gov.castVote(proposalId, 1);

// 或者带理由投票
gov.castVoteWithReason(proposalId, 1, "支持理由");
```

### 3. 提案执行
```solidity
// 投票通过后，将提案加入执行队列
gov.queue(proposalId);

// 等待时间锁期满后执行
gov.execute(proposalId);
```

## 治理参数

- **提案门槛**: 100,000 代币（可通过治理修改）
- **投票延迟**: 1 个区块
- **投票期间**: 17,280 个区块（约3天）
- **法定人数**: 总供应量的 4%
- **时间锁**: 2 天

## 部署和使用

### 1. 部署合约
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url

# 部署到本地网络
forge script script/DeployDAO.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### 2. 初始化设置
```solidity
// 1. 分发代币给社区成员
token.transfer(member1, amount1);
token.transfer(member2, amount2);

// 2. 成员委托投票权
token.delegate(member1); // 委托给自己
// 或
token.delegate(delegate); // 委托给其他人

// 3. 向银行存入资金
bank.depositEther{value: amount}();
bank.depositToken(tokenAddress, amount);
```

### 3. 创建和执行提案
```solidity
// 示例：提案从银行提取资金
address[] memory targets = new address[](1);
uint256[] memory values = new uint256[](1);
bytes[] memory calldatas = new bytes[](1);

targets[0] = address(bank);
values[0] = 0;
calldatas[0] = abi.encodeWithSignature(
    "withdraw(address,address,uint256)",
    address(token), // 提取的代币地址
    recipient,      // 接收者
    1000e18        // 提取数量
);

// 创建提案
uint256 proposalId = gov.propose(
    targets,
    values,
    calldatas,
    "提案：向开发团队支付1000代币"
);

// 等待投票开始
// ...

// 投票
gov.castVote(proposalId, 1); // 支持

// 等待投票结束
// ...

// 如果通过，加入执行队列
if (gov.state(proposalId) == Gov.ProposalState.Succeeded) {
    gov.queue(proposalId);
}

// 等待时间锁期满
// ...

// 执行提案
gov.execute(proposalId);
```

## 测试

运行完整的测试套件：

```bash
forge test --match-contract DAOTest -vv
```

测试覆盖了以下场景：
- ✅ 代币投票权委托
- ✅ 银行资金存取
- ✅ 提案创建和门槛检查
- ✅ 投票流程
- ✅ 提案执行
- ✅ 提案取消
- ✅ 法定人数要求
- ✅ 批量提取
- ✅ 紧急提取
- ✅ 权限控制
- ✅ 重复投票防护
- ✅ 时间锁机制

## 安全特性

1. **重入攻击防护**: 使用 ReentrancyGuard
2. **权限控制**: 只有治理合约可以操作银行资金
3. **时间锁**: 提案执行前有2天的延迟期
4. **投票权快照**: 防止闪电贷攻击
5. **法定人数**: 确保足够的参与度
6. **提案门槛**: 防止垃圾提案

## 注意事项

1. 在生产环境中使用前，请进行充分的安全审计
2. 治理参数可以通过治理流程进行修改
3. 确保私钥安全，避免治理攻击
4. 建议设置多重签名作为紧急措施

## 许可证

MIT License