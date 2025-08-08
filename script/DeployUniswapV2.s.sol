// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/uniswapv2/UniswapV2Factory.sol";
import "../src/uniswapv2/UniswapV2Router02.sol";
import {MockERC20} from "../src/MockERC20.sol";

/**
 * @title DeployUniswapV2
 * @dev 在本地anvil网络上部署UniswapV2合约的脚本
 */
contract DeployUniswapV2 is Script {
    // 部署的合约地址
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    MockERC20 public weth;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public usdc;
    
    // 初始供应量
    uint256 constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 constant LIQUIDITY_AMOUNT = 10000 * 10**18;
    
    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署代币合约
        console.log("\n=== Deploying Tokens ===");
        weth = new MockERC20("Wrapped Ether", "WETH", INITIAL_SUPPLY);
        tokenA = new MockERC20("Token A", "TKA", INITIAL_SUPPLY);
        tokenB = new MockERC20("Token B", "TKB", INITIAL_SUPPLY);
        usdc = new MockERC20("USD Coin", "USDC", INITIAL_SUPPLY);
        
        console.log("WETH deployed at:", address(weth));
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        console.log("USDC deployed at:", address(usdc));
        
        // 2. 部署UniswapV2工厂合约
        console.log("\n=== Deploying UniswapV2 Factory ===");
        factory = new UniswapV2Factory(deployer);
        console.log("Factory deployed at:", address(factory));
        
        // 3. 部署UniswapV2路由器合约
        console.log("\n=== Deploying UniswapV2 Router ===");
        router = new UniswapV2Router02(address(factory), address(weth));
        console.log("Router deployed at:", address(router));
        
        // 4. 授权路由器使用代币
        console.log("\n=== Approving Router ===");
        weth.approve(address(router), type(uint256).max);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        console.log("All tokens approved for router");
        
        // 5. 创建交易对并添加流动性
        console.log("\n=== Creating Pairs and Adding Liquidity ===");
        
        // TokenA/TokenB 交易对
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            deployer,
            block.timestamp + 1 hours
        );
        address pairAB = factory.getPair(address(tokenA), address(tokenB));
        console.log("TokenA/TokenB pair created at:", pairAB);
        
        // TokenA/USDC 交易对
        router.addLiquidity(
            address(tokenA),
            address(usdc),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            deployer,
            block.timestamp + 1 hours
        );
        address pairAU = factory.getPair(address(tokenA), address(usdc));
        console.log("TokenA/USDC pair created at:", pairAU);
        
        // WETH/USDC 交易对
        router.addLiquidity(
            address(weth),
            address(usdc),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            deployer,
            block.timestamp + 1 hours
        );
        address pairWU = factory.getPair(address(weth), address(usdc));
        console.log("WETH/USDC pair created at:", pairWU);
        
        vm.stopBroadcast();
        
        // 6. 输出部署摘要
        console.log("\n=== Deployment Summary ===");
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("WETH:", address(weth));
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        console.log("USDC:", address(usdc));
        console.log("\nPairs:");
        console.log("TokenA/TokenB:", pairAB);
        console.log("TokenA/USDC:", pairAU);
        console.log("WETH/USDC:", pairWU);
        console.log("\nTotal pairs created:", factory.allPairsLength());
        
        // 7. 保存部署信息到文件
        string memory deploymentInfo = string.concat(
            "# UniswapV2 Deployment on Anvil\n\n",
            "## Contract Addresses\n",
            "- Factory: ", vm.toString(address(factory)), "\n",
            "- Router: ", vm.toString(address(router)), "\n",
            "- WETH: ", vm.toString(address(weth)), "\n",
            "- TokenA: ", vm.toString(address(tokenA)), "\n",
            "- TokenB: ", vm.toString(address(tokenB)), "\n",
            "- USDC: ", vm.toString(address(usdc)), "\n\n",
            "## Trading Pairs\n",
            "- TokenA/TokenB: ", vm.toString(pairAB), "\n",
            "- TokenA/USDC: ", vm.toString(pairAU), "\n",
            "- WETH/USDC: ", vm.toString(pairWU), "\n\n",
            "## Usage\n",
            "You can now interact with these contracts using the router address.\n",
            "All pairs have initial liquidity of 10,000 tokens each.\n"
        );
        
        vm.writeFile("./deployments/anvil-deployment.md", deploymentInfo);
        console.log("\nDeployment info saved to ./deployments/anvil-deployment.md");
    }
}