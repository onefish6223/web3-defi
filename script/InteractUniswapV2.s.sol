// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/uniswapv2/UniswapV2Factory.sol";
import "../src/uniswapv2/UniswapV2Router02.sol";
import "../src/uniswapv2/UniswapV2Pair.sol";
import {MockERC20} from "../src/MockERC20.sol";

/**
 * @title InteractUniswapV2
 * @dev 与已部署的UniswapV2合约交互的示例脚本
 */
contract InteractUniswapV2 is Script {
    // 需要根据实际部署地址修改这些地址
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant ROUTER_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address constant TOKEN_A_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant TOKEN_B_ADDRESS = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant USDC_ADDRESS = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
    
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 usdc;
    
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);
        
        // 初始化合约实例
        factory = UniswapV2Factory(FACTORY_ADDRESS);
        router = UniswapV2Router02(payable(ROUTER_ADDRESS));
        tokenA = MockERC20(TOKEN_A_ADDRESS);
        tokenB = MockERC20(TOKEN_B_ADDRESS);
        usdc = MockERC20(USDC_ADDRESS);
        
        console.log("=== UniswapV2 Interaction Example ===");
        console.log("User address:", user);
        
        vm.startBroadcast(userPrivateKey);
        
        // 示例1: 查看余额
        showBalances(user);
        
        // 示例2: 代币交换 (TokenA -> TokenB)
        swapTokens();
        
        // 示例3: 添加流动性
        addLiquidity();
        
        // 示例4: 查看交易对信息
        showPairInfo();
        
        vm.stopBroadcast();
    }
    
    function showBalances(address user) internal view {
        console.log("\n=== User Balances ===");
        console.log("TokenA:", tokenA.balanceOf(user));
        console.log("TokenB:", tokenB.balanceOf(user));
        console.log("USDC:", usdc.balanceOf(user));
    }
    
    function swapTokens() internal {
        console.log("\n=== Token Swap Example ===");
        
        uint256 amountIn = 1000 * 10**18; // 1000 TokenA
        uint256 amountOutMin = 0; // 接受任何数量的输出（仅用于演示）
        
        // 确保有足够的授权
        tokenA.approve(address(router), amountIn);
        
        // 构建交换路径
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        console.log("TokenA balance before swap:", tokenA.balanceOf(msg.sender));
        console.log("TokenB balance before swap:", tokenB.balanceOf(msg.sender));
        
        // 执行交换
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 1 hours
        );
        
        console.log("TokenA balance after swap:", tokenA.balanceOf(msg.sender));
        console.log("TokenB balance after swap:", tokenB.balanceOf(msg.sender));
        console.log("Input amount:", amounts[0]);
        console.log("Output amount:", amounts[1]);
    }
    
    function addLiquidity() internal {
        console.log("\n=== Add Liquidity Example ===");
        
        uint256 amountA = 500 * 10**18;
        uint256 amountB = 500 * 10**18;
        
        // 授权
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        console.log("TokenA balance before adding liquidity:", tokenA.balanceOf(msg.sender));
        console.log("TokenB balance before adding liquidity:", tokenB.balanceOf(msg.sender));
        
        // 添加流动性
        (uint256 amountAUsed, uint256 amountBUsed, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            msg.sender,
            block.timestamp + 1 hours
        );
        
        console.log("TokenA balance after adding liquidity:", tokenA.balanceOf(msg.sender));
        console.log("TokenB balance after adding liquidity:", tokenB.balanceOf(msg.sender));
        console.log("TokenA used:", amountAUsed);
        console.log("TokenB used:", amountBUsed);
        console.log("Liquidity tokens received:", liquidity);
    }
    
    function showPairInfo() internal view {
        console.log("\n=== Pair Information ===");
        
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        console.log("TokenA/TokenB pair address:", pairAddress);
        
        if (pairAddress != address(0)) {
            UniswapV2Pair pair = UniswapV2Pair(pairAddress);
            (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
            
            console.log("Reserve0:", uint256(reserve0));
            console.log("Reserve1:", uint256(reserve1));
            console.log("Last update time:", uint256(blockTimestampLast));
            console.log("Total supply:", pair.totalSupply());
            
            // Display prices
            if (reserve0 > 0 && reserve1 > 0) {
                console.log("Token0 price (in Token1):", (uint256(reserve1) * 10**18) / uint256(reserve0));
                console.log("Token1 price (in Token0):", (uint256(reserve0) * 10**18) / uint256(reserve1));
            }
        }
        
        console.log("\nFactory contract info:");
        console.log("Total pairs count:", factory.allPairsLength());
        console.log("Fee recipient:", factory.feeTo());
        console.log("Fee setter:", factory.feeToSetter());
    }
}