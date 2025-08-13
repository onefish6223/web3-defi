// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/rebasetoken/DeflationaryRebaseToken.sol";

contract DeflationaryRebaseTokenTest is Test {
    DeflationaryRebaseToken public token;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿
    uint256 constant REBASE_INTERVAL = 365 days;
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        token = new DeflationaryRebaseToken();
    }
    
    // wake-disable
    function testInitialState() public {
        // 测试初始状态
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.rawBalanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.getRebaseMultiplier(), 1e18);
        assertEq(token.name(), "Deflationary Rebase Token");
        assertEq(token.symbol(), "DRT");
        assertEq(token.decimals(), 18);
    }
    
    function testTransfer() public {
        uint256 transferAmount = 1000 * 10**18;
        
        // 转账给 user1
        token.transfer(user1, transferAmount);
        
        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.rawBalanceOf(user1), transferAmount);
    }
    
    function testRebaseNotAllowedTooEarly() public {
        // 测试过早调用 rebase 会失败
        vm.expectRevert("Rebase: Too early to rebase");
        token.rebase();
    }
    
    function testCanRebase() public {
        // 初始时不能 rebase
        assertFalse(token.canRebase());
        
        // 时间推进一年后可以 rebase
        vm.warp(block.timestamp + REBASE_INTERVAL);
        assertTrue(token.canRebase());
    }
    
    function testTimeUntilNextRebase() public {
        uint256 timeUntilNext = token.timeUntilNextRebase();
        assertEq(timeUntilNext, REBASE_INTERVAL);
        
        // 推进一半时间
        vm.warp(block.timestamp + REBASE_INTERVAL / 2);
        timeUntilNext = token.timeUntilNextRebase();
        assertEq(timeUntilNext, REBASE_INTERVAL / 2);
        
        // 推进到可以 rebase 的时间
        vm.warp(block.timestamp + REBASE_INTERVAL / 2);
        timeUntilNext = token.timeUntilNextRebase();
        assertEq(timeUntilNext, 0);
    }
    
    function testRebaseAfterOneYear() public {
        uint256 transferAmount = 10_000_000 * 10**18; // 1000万
        
        // 先转账给用户
        token.transfer(user1, transferAmount);
        token.transfer(user2, transferAmount);
        
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 totalSupplyBefore = token.totalSupply();
        
        // 推进时间一年
        vm.warp(block.timestamp + REBASE_INTERVAL);
        
        // 执行 rebase
        vm.expectEmit(true, true, true, true);
        emit DeflationaryRebaseToken.Rebase(0.99e18, totalSupplyBefore * 99 / 100);
        token.rebase();
        
        // 检查 rebase 后的状态
        uint256 expectedMultiplier = 0.99e18; // 99%
        assertEq(token.getRebaseMultiplier(), expectedMultiplier);
        
        // 检查余额是否正确通缩了 1%
        assertEq(token.balanceOf(owner), ownerBalanceBefore * 99 / 100);
        assertEq(token.balanceOf(user1), user1BalanceBefore * 99 / 100);
        assertEq(token.balanceOf(user2), user2BalanceBefore * 99 / 100);
        assertEq(token.totalSupply(), totalSupplyBefore * 99 / 100);
        
        // 原始余额应该保持不变
        assertEq(token.rawBalanceOf(owner), INITIAL_SUPPLY - transferAmount * 2);
        assertEq(token.rawBalanceOf(user1), transferAmount);
        assertEq(token.rawBalanceOf(user2), transferAmount);
    }
    
    function testMultipleRebase() public {
        uint256 transferAmount = 10_000_000 * 10**18;
        token.transfer(user1, transferAmount);
        
        uint256 initialBalance = token.balanceOf(user1);
        
        // 第一次 rebase (一年后)
        vm.warp(block.timestamp + REBASE_INTERVAL);
        token.rebase();
        
        uint256 balanceAfterFirstRebase = token.balanceOf(user1);
        assertEq(balanceAfterFirstRebase, initialBalance * 99 / 100);
        
        // 第二次 rebase (再过一年)
        vm.warp(block.timestamp + REBASE_INTERVAL);
        token.rebase();
        
        uint256 balanceAfterSecondRebase = token.balanceOf(user1);
        // 第二次应该是在第一次基础上再通缩 1%
        assertEq(balanceAfterSecondRebase, balanceAfterFirstRebase * 99 / 100);
        
        // 验证累计通缩效果：(0.99)^2 = 0.9801
        uint256 expectedBalance = (initialBalance * 99 * 99) / (100 * 100);
        assertEq(balanceAfterSecondRebase, expectedBalance);
    }
    
    function testTransferAfterRebase() public {
        uint256 transferAmount = 1000 * 10**18;
        token.transfer(user1, transferAmount);
        
        // 执行 rebase
        vm.warp(block.timestamp + REBASE_INTERVAL);
        token.rebase();
        
        uint256 user1BalanceAfterRebase = token.balanceOf(user1);
        
        // rebase 后进行转账
        vm.prank(user1);
        token.transfer(user2, user1BalanceAfterRebase / 2);
        
        assertEq(token.balanceOf(user1), user1BalanceAfterRebase / 2);
        assertEq(token.balanceOf(user2), user1BalanceAfterRebase / 2);
    }
    
    function testForceRebase() public {
        uint256 initialBalance = token.balanceOf(owner);
        
        // 使用 forceRebase（仅限所有者）
        token.forceRebase();
        
        assertEq(token.balanceOf(owner), initialBalance * 99 / 100);
        assertEq(token.getRebaseMultiplier(), 0.99e18);
    }
    
    function testForceRebaseOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.forceRebase();
    }
    
    function testMintAndBurn() public {
        uint256 mintAmount = 1000 * 10**18;
        
        // 铸造代币
        token.mint(user1, mintAmount);
        assertEq(token.balanceOf(user1), mintAmount);
        
        // 销毁代币
        vm.prank(user1);
        token.burn(mintAmount / 2);
        assertEq(token.balanceOf(user1), mintAmount / 2);
    }
    
    function testMintOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1000 * 10**18);
    }
    
    function testBurnExceedsBalance() public {
        vm.prank(user1);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.burn(1000 * 10**18);
    }
    
    function testRebasePreservesProportions() public {
        // 分配代币给多个用户
        uint256 amount1 = 30_000_000 * 10**18; // 30%
        uint256 amount2 = 20_000_000 * 10**18; // 20%
        // owner 保留 50%
        
        token.transfer(user1, amount1);
        token.transfer(user2, amount2);
        
        uint256 ownerBalance = token.balanceOf(owner);
        uint256 user1Balance = token.balanceOf(user1);
        uint256 user2Balance = token.balanceOf(user2);
        uint256 totalBefore = token.totalSupply();
        
        // 执行 rebase
        vm.warp(block.timestamp + REBASE_INTERVAL);
        token.rebase();
        
        uint256 totalAfter = token.totalSupply();
        
        // 验证比例保持不变
        assertEq(token.balanceOf(owner) * 100 / totalAfter, ownerBalance * 100 / totalBefore);
        assertEq(token.balanceOf(user1) * 100 / totalAfter, user1Balance * 100 / totalBefore);
        assertEq(token.balanceOf(user2) * 100 / totalAfter, user2Balance * 100 / totalBefore);
    }
    
    function testLongTermDeflation() public {
        uint256 initialSupply = token.totalSupply();
        
        // 模拟 10 年的通缩
        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + REBASE_INTERVAL);
            token.rebase();
        }
        
        uint256 finalSupply = token.totalSupply();
        
        // 10年后，供应量应该约为初始供应量的 (0.99)^10 ≈ 0.904
        // 由于整数除法的舍入误差，我们使用范围检查而不是精确相等
        
        // 验证约为 90.4% 的初始供应量，允许小的精度误差
        uint256 expectedMin = initialSupply * 904 / 1000; // 90.4%
        uint256 expectedMax = initialSupply * 905 / 1000; // 90.5%
        
        assertTrue(finalSupply >= expectedMin, "Final supply too low");
        assertTrue(finalSupply <= expectedMax, "Final supply too high");
        
        // 额外验证：确保确实发生了通缩
        assertTrue(finalSupply < initialSupply, "No deflation occurred");
    }
}