// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";

/**
 * @title DeploySepolia
 * @dev Sepolia测试网部署脚本
 */
contract DeploySepolia is Script {
    // Sepolia网络上的已知合约地址
    address constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant UNISWAP_V2_FACTORY = 0x7E0987E5b3a30e3f2828572Bb659A548460a3003;
    address constant UNISWAP_V2_ROUTER = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying on Sepolia testnet...");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        
        // 部署两个自定义代币
        MyToken tokenA = new MyToken(
            "Arbitrage Token A",
            "ARBA",
            18,
            10000000, // 10M tokens
            deployer
        );
        
        MyToken tokenB = new MyToken(
            "Arbitrage Token B",
            "ARBB",
            18,
            10000000, // 10M tokens
            deployer
        );
        
        console.log("Token A deployed:", address(tokenA));
        console.log("Token B deployed:", address(tokenB));
        
        // 注意：在Sepolia上，我们需要手动创建两个不同的Uniswap实例
        // 或者使用现有的DEX来创建价差
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Next steps:");
        console.log("1. Create liquidity pools on different DEXs");
        console.log("2. Deploy arbitrage contract with factory addresses");
        console.log("3. Add liquidity with different ratios to create price differences");
    }
}