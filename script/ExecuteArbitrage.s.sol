// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "../src/MyToken.sol";
import "../src/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../src/uniswapv2/interfaces/IUniswapV2Factory.sol";

/**
 * @title ExecuteArbitrage
 * @dev 执行套利操作的脚本
 */
  // wake-disable
contract ExecuteArbitrage is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 从环境变量获取合约地址
        address arbitrageAddress = vm.envAddress("ARBITRAGE_CONTRACT");
        address tokenAAddress = vm.envAddress("TOKEN_A");
        address tokenBAddress = vm.envAddress("TOKEN_B");
        address factoryAAddress = vm.envAddress("FACTORY_A");
        address factoryBAddress = vm.envAddress("FACTORY_B");
        
        vm.startBroadcast(deployerPrivateKey);
        
        FlashSwapArbitrage arbitrage = FlashSwapArbitrage(arbitrageAddress);
        MyToken tokenA = MyToken(tokenAAddress);
        MyToken tokenB = MyToken(tokenBAddress);
        
        console.log("Executing arbitrage...");
        console.log("Arbitrage contract:", arbitrageAddress);
        console.log("Token A:", tokenAAddress);
        console.log("Token B:", tokenBAddress);
        
        // 检查池子价格
        _checkPoolPrices(factoryAAddress, factoryBAddress, tokenAAddress, tokenBAddress);
        
        // 执行套利（借入10个Token A）
        uint256 borrowAmount = 10 * 10**18;
        
        try arbitrage.executeArbitrage(
            tokenAAddress,
            tokenBAddress,
            borrowAmount,
            true // 从池子A借入tokenA，在池子B兑换
        ) {
            console.log("Arbitrage executed successfully!");
            
            // 检查利润
            uint256 profitA = arbitrage.getTokenBalance(tokenAAddress);
            uint256 profitB = arbitrage.getTokenBalance(tokenBAddress);
            
            console.log("Profit Token A:", profitA);
            console.log("Profit Token B:", profitB);
            
        } catch Error(string memory reason) {
            console.log("Arbitrage failed:", reason);
        }
        
        vm.stopBroadcast();
    }
    
    function _checkPoolPrices(
        address factoryA,
        address factoryB,
        address tokenA,
        address tokenB
    ) internal view {
        console.log("\n=== Pool Price Check ===");
        
        // 获取池子地址
        address pairA = IUniswapV2Factory(factoryA).getPair(tokenA, tokenB);
        address pairB = IUniswapV2Factory(factoryB).getPair(tokenA, tokenB);
        
        if (pairA != address(0)) {
            (uint256 reserve0A, uint256 reserve1A,) = IUniswapV2Pair(pairA).getReserves();
            console.log("Pool A reserves:", reserve0A, reserve1A);
        }
        
        if (pairB != address(0)) {
            (uint256 reserve0B, uint256 reserve1B,) = IUniswapV2Pair(pairB).getReserves();
            console.log("Pool B reserves:", reserve0B, reserve1B);
        }
    }
}