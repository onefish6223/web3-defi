// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/stakingpool/StakingPool.sol";
import "../src/stakingpool/KKToken.sol";

/**
 * @title InteractStakingPool
 * @dev 与质押池交互的示例脚本
 */
contract InteractStakingPool is Script {
    // 合约地址（需要根据实际部署地址修改）
    address constant STAKING_POOL = 0x2e234DAe75C793f67A35089C9d99245E1C58470b;
    address constant KK_TOKEN = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(userPrivateKey);
        
        StakingPool stakingPool = StakingPool(payable(STAKING_POOL));
        KKToken kkToken = KKToken(KK_TOKEN);
        
        vm.startBroadcast(userPrivateKey);
        
        console.log("=== StakingPool Interaction Demo ===");
        console.log("User address:", user);
        console.log("User ETH balance:", user.balance / 1e18, "ETH");
        
        // 1. 质押 ETH
        uint256 stakeAmount = 1 ether;
        console.log("\n1. Staking", stakeAmount / 1e18, "ETH...");
        
        uint256 balanceBefore = stakingPool.balanceOf(user);
        stakingPool.stake{value: stakeAmount}();
        uint256 balanceAfter = stakingPool.balanceOf(user);
        
        console.log("Staked amount:", (balanceAfter - balanceBefore) / 1e18, "ETH");
        console.log("Total staked:", stakingPool.balanceOf(user) / 1e18, "ETH");
        
        // 2. 检查奖励（需要等待一些区块）
        console.log("\n2. Checking rewards...");
        uint256 earned = stakingPool.earned(user);
        console.log("Current rewards:", earned / 1e18, "KK");
        
        // 3. 领取奖励（如果有的话）
        if (earned > 0) {
            console.log("\n3. Claiming rewards...");
            uint256 kkBalanceBefore = kkToken.balanceOf(user);
            stakingPool.claim();
            uint256 kkBalanceAfter = kkToken.balanceOf(user);
            console.log("Claimed rewards:", (kkBalanceAfter - kkBalanceBefore) / 1e18, "KK");
        }
        
        // 4. 部分解除质押
        uint256 unstakeAmount = stakeAmount / 2;
        console.log("\n4. Unstaking", unstakeAmount / 1e18, "ETH...");
        
        uint256 ethBalanceBefore = user.balance;
        uint256 stakedBefore = stakingPool.balanceOf(user);
        
        stakingPool.unstake(unstakeAmount);
        
        uint256 ethBalanceAfter = user.balance;
        uint256 stakedAfter = stakingPool.balanceOf(user);
        
        console.log("ETH returned:", (ethBalanceAfter - ethBalanceBefore) / 1e18, "ETH");
        console.log("Remaining staked:", stakedAfter / 1e18, "ETH");
        console.log("Unstaked amount:", (stakedBefore - stakedAfter) / 1e18, "ETH");
        
        // 5. 最终状态
        console.log("\n=== Final State ===");
        console.log("User ETH balance:", user.balance / 1e18, "ETH");
        console.log("User KK balance:", kkToken.balanceOf(user) / 1e18, "KK");
        console.log("User staked amount:", stakingPool.balanceOf(user) / 1e18, "ETH");
        console.log("Pending rewards:", stakingPool.earned(user) / 1e18, "KK");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev 查看质押池状态的只读函数
     */
    function viewPoolStatus() external view {
        StakingPool stakingPool = StakingPool(payable(STAKING_POOL));
        
        console.log("=== StakingPool Status ===");
        console.log("Total staked:", stakingPool.totalStaked() / 1e18, "ETH");
        console.log("Last reward block:", stakingPool.lastRewardBlock());
        console.log("Current block:", block.number);
        console.log("Reward per block:", 10, "KK");
        
        // 如果设置了借贷池，显示借贷池余额
        try stakingPool.getLendingBalance() returns (uint256 lendingBalance) {
            console.log("Lending pool balance:", lendingBalance / 1e18, "ETH");
        } catch {
            console.log("Lending pool not set or error");
        }
    }
}