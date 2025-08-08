#!/bin/bash

# UniswapV2 本地部署脚本
# 使用方法: ./deploy.sh

set -e

echo "🚀 UniswapV2 本地部署脚本"
echo "========================="

# 检查是否安装了 forge
if ! command -v forge &> /dev/null; then
    echo "❌ 错误: 未找到 forge 命令"
    echo "请先安装 Foundry: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# 检查是否安装了 anvil
if ! command -v anvil &> /dev/null; then
    echo "❌ 错误: 未找到 anvil 命令"
    echo "请先安装 Foundry: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# 创建 .env 文件（如果不存在）
if [ ! -f ".env" ]; then
    echo "📝 创建 .env 文件..."
    cp .env.example .env
    echo "✅ .env 文件已创建"
fi

# 检查 Anvil 是否正在运行
echo "🔍 检查 Anvil 网络状态..."
if curl -s -X POST -H "Content-Type: application/json" \
   --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
   http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo "✅ Anvil 网络已运行"
else
    echo "❌ Anvil 网络未运行"
    echo "请在另一个终端窗口中运行: anvil"
    echo "然后重新执行此脚本"
    exit 1
fi

# 安装依赖
echo "📦 安装项目依赖..."
forge install --no-commit

# 编译合约
echo "🔨 编译合约..."
forge build

# 运行测试
echo "🧪 运行测试..."
forge test

if [ $? -ne 0 ]; then
    echo "❌ 测试失败，请检查代码"
    exit 1
fi

echo "✅ 所有测试通过"

# 部署合约
echo "🚀 部署 UniswapV2 合约..."
forge script script/DeployUniswapV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 部署成功！"
    echo "========================="
    echo "📄 部署信息已保存到: ./deployments/anvil-deployment.md"
    echo "📚 查看使用指南: ./deployments/README.md"
    echo ""
    echo "💡 提示:"
    echo "- 使用 'forge test' 运行测试"
    echo "- 查看 deployments/ 目录获取合约地址"
    echo "- 参考 deployments/README.md 了解如何与合约交互"
else
    echo "❌ 部署失败，请检查错误信息"
    exit 1
fi