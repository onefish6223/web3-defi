// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import {UniswapV2Factory} from "../src/uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../src/uniswapv2/UniswapV2Router02.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "../src/WETH.sol";

/**
 * @title DeployArbitrageSystem
 * @dev 部署完整的套利系统：代币、Uniswap工厂、路由器、流动池和套利合约
 */
contract DeployArbitrageSystem is Script {
    // 部署的合约地址
    MyToken public tokenA;
    MyToken public tokenB;
    WETH public weth;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    UniswapV2Router02 public routerA;
    UniswapV2Router02 public routerB;
    FlashSwapArbitrage public arbitrage;
    
    // 流动池地址
    address public pairA;
    address public pairB;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        // 1. 部署WETH
        weth = new WETH();
        console.log("WETH deployed at:", address(weth));
        
        // 2. 部署两个代币
        tokenA = new MyToken(
            "Token A",
            "TKA",
            18,
            1000000, // 1M tokens
            deployer
        );
        console.log("Token A deployed at:", address(tokenA));
        
        tokenB = new MyToken(
            "Token B",
            "TKB",
            18,
            1000000, // 1M tokens
            deployer
        );
        console.log("Token B deployed at:", address(tokenB));
        
        // 3. 部署两个Uniswap V2工厂
        factoryA = new UniswapV2Factory(deployer);
        console.log("Factory A deployed at:", address(factoryA));
        
        factoryB = new UniswapV2Factory(deployer);
        console.log("Factory B deployed at:", address(factoryB));
        
        // 4. 部署两个路由器
        routerA = new UniswapV2Router02(address(factoryA), address(weth));
        console.log("Router A deployed at:", address(routerA));
        
        routerB = new UniswapV2Router02(address(factoryB), address(weth));
        console.log("Router B deployed at:", address(routerB));
        
        // 5. 创建流动池
        pairA = factoryA.createPair(address(tokenA), address(tokenB));
        console.log("Pair A created at:", pairA);
        
        pairB = factoryB.createPair(address(tokenA), address(tokenB));
        console.log("Pair B created at:", pairB);
        
        // 6. 添加流动性到池子A（比例 1:2）
        uint256 amountA1 = 100000 * 10**18; // 100k Token A
        uint256 amountB1 = 200000 * 10**18; // 200k Token B
        
        tokenA.approve(address(routerA), amountA1);
        tokenB.approve(address(routerA), amountB1);
        
        routerA.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA1,
            amountB1,
            amountA1 * 95 / 100, // 5% slippage
            amountB1 * 95 / 100,
            deployer,
            block.timestamp + 300
        );
        console.log("Liquidity added to Pair A");
        
        // 7. 添加流动性到池子B（比例 1:1.8，创造价差）
        uint256 amountA2 = 100000 * 10**18; // 100k Token A
        uint256 amountB2 = 180000 * 10**18; // 180k Token B
        
        tokenA.approve(address(routerB), amountA2);
        tokenB.approve(address(routerB), amountB2);
        
        routerB.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA2,
            amountB2,
            amountA2 * 95 / 100,
            amountB2 * 95 / 100,
            deployer,
            block.timestamp + 300
        );
        console.log("Liquidity added to Pair B");
        
        // 8. 部署套利合约
        arbitrage = new FlashSwapArbitrage(
            address(factoryA),
            address(factoryB),
            deployer
        );
        console.log("Arbitrage contract deployed at:", address(arbitrage));
        
        vm.stopBroadcast();
        
        // 输出部署信息
        _printDeploymentInfo();
    }
    
    function _printDeploymentInfo() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("WETH:", address(weth));
        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        console.log("Factory A:", address(factoryA));
        console.log("Factory B:", address(factoryB));
        console.log("Router A:", address(routerA));
        console.log("Router B:", address(routerB));
        console.log("Pair A:", pairA);
        console.log("Pair B:", pairB);
        console.log("Arbitrage:", address(arbitrage));
        console.log("\n=== Price Information ===");
        console.log("Pool A ratio: 1 TKA = 2 TKB");
        console.log("Pool B ratio: 1 TKA = 1.8 TKB");
        console.log("Arbitrage opportunity: Buy TKB cheap in Pool B, sell expensive in Pool A");
    }
}