// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/stakingpool/KKToken.sol";
import "../src/stakingpool/StakingPool.sol";
import "../src/stakingpool/MockLendingPool.sol";

/**
 * @title DeployStakingPool
 * @dev 部署质押池系统的脚本
 */
contract DeployStakingPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 KK Token
        console.log("Deploying KK Token...");
        KKToken kkToken = new KKToken();
        console.log("KK Token deployed at:", address(kkToken));
        
        // 2. 部署质押池
        console.log("Deploying Staking Pool...");
        StakingPool stakingPool = new StakingPool(address(kkToken));
        console.log("Staking Pool deployed at:", address(stakingPool));
        
        // 3. 部署模拟借贷市场
        console.log("Deploying Mock Lending Pool...");
        MockLendingPool lendingPool = new MockLendingPool();
        console.log("Mock Lending Pool deployed at:", address(lendingPool));
        
        // 4. 将 KK Token 的所有权转移给质押池
        console.log("Transferring KK Token ownership to Staking Pool...");
        kkToken.transferOwnership(address(stakingPool));
        
        // 5. 设置质押池的借贷市场
        console.log("Setting lending pool in Staking Pool...");
        stakingPool.setLendingPool(address(lendingPool));
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("KK Token:", address(kkToken));
        console.log("Staking Pool:", address(stakingPool));
        console.log("Mock Lending Pool:", address(lendingPool));
        console.log("\n=== Usage Instructions ===");
        console.log("1. Users can stake ETH by calling stakingPool.stake() with ETH value");
        console.log("2. Users earn KK tokens at 10 KK per block based on their stake proportion");
        console.log("3. Staked ETH is deposited into the lending pool to earn interest");
        console.log("4. Users can claim KK token rewards by calling stakingPool.claim()");
        console.log("5. Users can unstake ETH by calling stakingPool.unstake(amount)");
    }
}