// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/option/CallOption.sol";
import "../src/MockERC20.sol";

// wake-disable
contract CallOptionTest is Test {
    CallOption public callOption;
    MockERC20 public usdtToken;
    
    address public owner = address(0x123);
    address public user1 = address(0x456);
    address public user2 = address(0x789);
    
    uint256 public constant STRIKE_PRICE = 2000e6; // 2000 USDT per ETH (6 decimals)
    uint256 public constant UNDERLYING_PRICE = 1800e6; // 1800 USDT per ETH (6 decimals)
    uint256 public constant EXPIRATION_DAYS = 30;
    
    function setUp() public {
        // 部署USDT代币
        usdtToken = new MockERC20("USDT", "USDT", 6);
        
        // 设置到期日期（30天后）
        uint256 expirationDate = block.timestamp + EXPIRATION_DAYS * 1 days;
        
        // 部署期权合约
        vm.prank(owner);
        callOption = new CallOption(
            "ETH Call Option",
            "ETH-CALL",
            STRIKE_PRICE,
            expirationDate,
            UNDERLYING_PRICE,
            address(0), // ETH
            address(usdtToken)
        );
        
        // 给用户分配USDT
        usdtToken.mint(user1, 100000e6); // 100,000 USDT
        usdtToken.mint(user2, 100000e6); // 100,000 USDT
        
        // 给测试账户一些ETH
        vm.deal(owner, 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    function testInitialState() public {
        assertEq(callOption.strikePrice(), STRIKE_PRICE);
        assertEq(callOption.underlyingPrice(), UNDERLYING_PRICE);
        assertEq(callOption.underlyingAsset(), address(0));
        assertEq(callOption.usdtToken(), address(usdtToken));
        assertFalse(callOption.isExpired());
        assertEq(callOption.totalSupply(), 0);
    }
    
    function testIssueOptions() public {
        uint256 ethAmount = 5 ether;
        
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        assertEq(callOption.totalSupply(), ethAmount);
        assertEq(callOption.balanceOf(owner), ethAmount);
        assertEq(callOption.totalUnderlyingDeposited(), ethAmount);
        assertEq(address(callOption).balance, ethAmount);
    }
    
    function testCannotIssueOptionsAfterExpiration() public {
        // 快进到过期后
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days + 1);
        
        vm.prank(owner);
        vm.expectRevert("Cannot issue after expiration");
        callOption.issueOptions{value: 1 ether}();
    }
    
    function testTransferOptions() public {
        uint256 ethAmount = 5 ether;
        
        // 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 转移期权给用户
        vm.prank(owner);
        callOption.transfer(user1, 2 ether);
        
        assertEq(callOption.balanceOf(owner), 3 ether);
        assertEq(callOption.balanceOf(user1), 2 ether);
    }
    
    function testExerciseOption() public {
        uint256 ethAmount = 5 ether;
        uint256 exerciseAmount = 2 ether;
        
        // 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 转移期权给用户
        vm.prank(owner);
        callOption.transfer(user1, exerciseAmount);
        
        // 快进到到期日
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days);
        
        // 计算需要的USDT
        uint256 usdtRequired = callOption.calculateExerciseCost(exerciseAmount);
        
        // 用户授权USDT
        vm.prank(user1);
        usdtToken.approve(address(callOption), usdtRequired);
        
        uint256 initialETHBalance = user1.balance;
        uint256 initialUSDTBalance = usdtToken.balanceOf(user1);
        
        // 行权
        vm.prank(user1);
        callOption.exerciseOption(exerciseAmount);
        
        // 检查结果
        assertEq(callOption.balanceOf(user1), 0); // 期权被销毁
        assertEq(user1.balance, initialETHBalance + exerciseAmount); // 收到ETH
        assertEq(usdtToken.balanceOf(user1), initialUSDTBalance - usdtRequired); // 支付了USDT
        assertEq(usdtToken.balanceOf(address(callOption)), usdtRequired); // 合约收到USDT
    }
    
    function testCannotExerciseBeforeExpiration() public {
        uint256 ethAmount = 5 ether;
        
        // 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 转移期权给用户
        vm.prank(owner);
        callOption.transfer(user1, 1 ether);
        
        // 尝试在到期前行权
        vm.prank(user1);
        vm.expectRevert("Cannot exercise before expiration date");
        callOption.exerciseOption(1 ether);
    }
    
    function testCannotExerciseAfterExercisePeriod() public {
        uint256 ethAmount = 5 ether;
        
        // 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 转移期权给用户
        vm.prank(owner);
        callOption.transfer(user1, 1 ether);
        
        // 快进到行权期结束后
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days + 2 days);
        
        // 尝试行权
        vm.prank(user1);
        vm.expectRevert("Exercise period has ended");
        callOption.exerciseOption(1 ether);
    }
    
    function testExpireOptions() public {
        uint256 ethAmount = 5 ether;
        
        // 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 快进到行权期结束后
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days + 2 days);
        
        uint256 initialOwnerBalance = owner.balance;
        
        // 过期销毁
        vm.prank(owner);
        callOption.expireOptions();
        
        assertTrue(callOption.isExpired());
        assertEq(owner.balance, initialOwnerBalance + ethAmount); // 项目方收回ETH
        assertEq(address(callOption).balance, 0);
    }
    
    function testCannotExpireBeforeExercisePeriodEnds() public {
        uint256 ethAmount = 5 ether;
        
        // 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 快进到到期日但行权期未结束
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days);
        
        // 尝试过期销毁
        vm.prank(owner);
        vm.expectRevert("Exercise period not ended yet");
        callOption.expireOptions();
    }
    
    function testUpdateUnderlyingPrice() public {
        uint256 newPrice = 2200e18;
        
        vm.prank(owner);
        callOption.updateUnderlyingPrice(newPrice);
        
        assertEq(callOption.underlyingPrice(), newPrice);
    }
    
    function testGetOptionDetails() public {
        (
            uint256 _strikePrice,
            uint256 _expirationDate,
            uint256 _underlyingPrice,
            address _underlyingAsset,
            address _usdtToken,
            bool _isExpired,
            uint256 _totalSupply,
            uint256 _totalUnderlyingDeposited
        ) = callOption.getOptionDetails();
        
        assertEq(_strikePrice, STRIKE_PRICE);
        assertEq(_underlyingPrice, UNDERLYING_PRICE);
        assertEq(_underlyingAsset, address(0));
        assertEq(_usdtToken, address(usdtToken));
        assertFalse(_isExpired);
        assertEq(_totalSupply, 0);
        assertEq(_totalUnderlyingDeposited, 0);
    }
    
    function testCanExercise() public {
        // 在到期前
        assertFalse(callOption.canExercise());
        
        // 在到期日
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days);
        assertTrue(callOption.canExercise());
        
        // 在行权期结束后
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days + 2 days);
        assertFalse(callOption.canExercise());
    }
    
    function testCalculateExerciseCost() public {
        uint256 optionAmount = 1 ether;
        uint256 expectedCost = (optionAmount * STRIKE_PRICE) / 1e18;
        
        assertEq(callOption.calculateExerciseCost(optionAmount), expectedCost);
    }
    
    function testCompleteOptionLifecycle() public {
        uint256 ethAmount = 10 ether;
        uint256 exerciseAmount = 3 ether;
        
        // 1. 发行期权
        vm.prank(owner);
        callOption.issueOptions{value: ethAmount}();
        
        // 2. 转移期权给用户
        vm.prank(owner);
        callOption.transfer(user1, exerciseAmount);
        
        // 3. 快进到到期日
        vm.warp(block.timestamp + EXPIRATION_DAYS * 1 days);
        
        // 4. 用户行权
        uint256 usdtRequired = callOption.calculateExerciseCost(exerciseAmount);
        vm.prank(user1);
        usdtToken.approve(address(callOption), usdtRequired);
        
        vm.prank(user1);
        callOption.exerciseOption(exerciseAmount);
        
        // 5. 快进到行权期结束
        vm.warp(block.timestamp + 2 days);
        
        // 6. 项目方过期销毁剩余期权
        uint256 initialOwnerBalance = owner.balance;
        uint256 initialOwnerUSDTBalance = usdtToken.balanceOf(owner);
        
        vm.prank(owner);
        callOption.expireOptions();
        
        // 验证最终状态
        assertTrue(callOption.isExpired());
        assertEq(owner.balance, initialOwnerBalance + (ethAmount - exerciseAmount)); // 收回未行权的ETH
        assertEq(usdtToken.balanceOf(owner), initialOwnerUSDTBalance + usdtRequired); // 收到行权的USDT
        assertEq(address(callOption).balance, 0);
        assertEq(usdtToken.balanceOf(address(callOption)), 0);
    }
}