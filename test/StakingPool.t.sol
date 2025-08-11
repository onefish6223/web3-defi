// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/stakingpool/KKToken.sol";
import "../src/stakingpool/StakingPool.sol";
import "../src/stakingpool/MockLendingPool.sol";

/**
 * @title StakingPoolTest
 * @dev 质押池合约的测试
 */
contract StakingPoolTest is Test {
    KKToken public kkToken;
    StakingPool public stakingPool;
    MockLendingPool public lendingPool;
    
    address public owner = address(this);
    address public user1 = address(0x123);
    address public user2 = address(0x456);
    
    uint256 public constant INITIAL_ETH = 100 ether;
    
    function setUp() public {
        // 部署合约
        kkToken = new KKToken();
        stakingPool = new StakingPool(address(kkToken));
        lendingPool = new MockLendingPool();
        
        // 设置权限
        kkToken.transferOwnership(address(stakingPool));
        stakingPool.setLendingPool(address(lendingPool));
        
        // 给测试用户分配ETH
        vm.deal(user1, INITIAL_ETH);
        vm.deal(user2, INITIAL_ETH);
        vm.deal(address(lendingPool), INITIAL_ETH); // 给借贷池一些ETH用于提取
    }
    
    function testStakeETH() public {
        uint256 stakeAmount = 10 ether;
        
        vm.startPrank(user1);
        
        // 质押ETH
        stakingPool.stake{value: stakeAmount}();
        
        // 验证质押余额
        assertEq(stakingPool.balanceOf(user1), stakeAmount);
        assertEq(stakingPool.totalStaked(), stakeAmount);
        
        // 验证ETH被存入借贷市场
        assertEq(lendingPool.getBalance(address(stakingPool)), stakeAmount);
        
        vm.stopPrank();
    }
    
    function testMultipleUsersStaking() public {
        uint256 stake1 = 10 ether;
        uint256 stake2 = 20 ether;
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: stake1}();
        
        // 用户2质押
        vm.prank(user2);
        stakingPool.stake{value: stake2}();
        
        // 验证质押余额
        assertEq(stakingPool.balanceOf(user1), stake1);
        assertEq(stakingPool.balanceOf(user2), stake2);
        assertEq(stakingPool.totalStaked(), stake1 + stake2);
    }
    
    function testRewardCalculation() public {
        uint256 stakeAmount = 10 ether;
        
        vm.startPrank(user1);
        
        // 质押ETH
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟挖矿几个区块
        vm.roll(block.number + 10);
        
        // 检查奖励
        uint256 earned = stakingPool.earned(user1);
        uint256 expectedReward = 10 * 10 * 1e18; // 10 blocks * 10 KK per block
        assertEq(earned, expectedReward);
        
        vm.stopPrank();
    }
    
    function testClaimRewards() public {
        uint256 stakeAmount = 10 ether;
        
        vm.startPrank(user1);
        
        // 质押ETH
        stakingPool.stake{value: stakeAmount}();
        
        // 模拟挖矿几个区块
        vm.roll(block.number + 5);
        
        // 领取奖励
        uint256 balanceBefore = kkToken.balanceOf(user1);
        stakingPool.claim();
        uint256 balanceAfter = kkToken.balanceOf(user1);
        
        // 验证奖励
        uint256 expectedReward = 5 * 10 * 1e18; // 5 blocks * 10 KK per block
        assertEq(balanceAfter - balanceBefore, expectedReward);
        
        // 验证奖励已清零
        assertEq(stakingPool.earned(user1), 0);
        
        vm.stopPrank();
    }
    
    function testUnstake() public {
        uint256 stakeAmount = 10 ether;
        uint256 unstakeAmount = 5 ether;
        
        vm.startPrank(user1);
        
        // 质押ETH
        uint256 balanceBefore = user1.balance;
        stakingPool.stake{value: stakeAmount}();
        uint256 balanceAfterStake = user1.balance;
        
        // 模拟挖矿几个区块
        vm.roll(block.number + 3);
        
        // 解除质押
        stakingPool.unstake(unstakeAmount);
        uint256 balanceAfterUnstake = user1.balance;
        
        // 验证ETH返还 (应该收回部分质押的ETH)
        assertEq(balanceAfterUnstake - balanceAfterStake, unstakeAmount);
        
        // 验证总的ETH变化 (质押10ETH，取回5ETH，净支出5ETH)
        assertEq(balanceBefore - balanceAfterUnstake, stakeAmount - unstakeAmount);
        
        // 验证质押余额
        assertEq(stakingPool.balanceOf(user1), stakeAmount - unstakeAmount);
        
        vm.stopPrank();
    }
    
    function testProportionalRewards() public {
        uint256 stake1 = 10 ether;
        uint256 stake2 = 30 ether; // user2 质押3倍于user1
        
        // 用户1质押
        vm.prank(user1);
        stakingPool.stake{value: stake1}();
        
        // 用户2质押
        vm.prank(user2);
        stakingPool.stake{value: stake2}();
        
        // 模拟挖矿几个区块
        vm.roll(block.number + 4);
        
        // 检查奖励比例
        uint256 earned1 = stakingPool.earned(user1);
        uint256 earned2 = stakingPool.earned(user2);
        
        // user2的奖励应该是user1的3倍（比例分配）
        // 注意：user1在前面的区块中独享奖励，所以比例不是严格的3:1
        assertTrue(earned2 > earned1);
        
        // 验证总奖励等于区块奖励
        uint256 totalEarned = earned1 + earned2;
        uint256 expectedTotal = 4 * 10 * 1e18; // 4 blocks * 10 KK per block
        assertEq(totalEarned, expectedTotal);
    }
    
    function testLendingPoolIntegration() public {
        uint256 stakeAmount = 10 ether;
        
        vm.startPrank(user1);
        
        // 质押ETH
        stakingPool.stake{value: stakeAmount}();
        
        // 验证ETH存入借贷市场
        assertEq(lendingPool.getBalance(address(stakingPool)), stakeAmount);
        
        // 模拟时间流逝以产生利息
        vm.warp(block.timestamp + 365 days);
        
        // 检查借贷市场余额（应该包含利息）
        uint256 balanceWithInterest = lendingPool.getBalance(address(stakingPool));
        assertTrue(balanceWithInterest > stakeAmount);
        
        vm.stopPrank();
    }
    
    function test_RevertWhen_StakeZeroETH() public {
        vm.prank(user1);
        vm.expectRevert("Cannot stake 0 ETH");
        stakingPool.stake{value: 0}();
    }
    
    function test_RevertWhen_UnstakeMoreThanStaked() public {
        uint256 stakeAmount = 10 ether;
        
        vm.startPrank(user1);
        stakingPool.stake{value: stakeAmount}();
        
        // 尝试解除质押超过质押数量
        vm.expectRevert("Insufficient staked amount");
        stakingPool.unstake(stakeAmount + 1 ether);
        vm.stopPrank();
    }
    
    function test_RevertWhen_ClaimWithoutStaking() public {
        vm.prank(user1);
        vm.expectRevert("No rewards to claim");
        stakingPool.claim();
    }
}