// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenVesting.sol";
import "../src/MockERC20.sol";

contract TokenVestingTest is Test {
    TokenVesting public vesting;
    MockERC20 public token;
    
    address public owner = address(0x1);
    address public beneficiary = address(0x2);
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 10**18; // 1 million tokens
    uint256 public constant CLIFF_DURATION = 365 days; // 12 months
    uint256 public constant VESTING_DURATION = 730 days; // 24 months
    
    event TokensReleased(address token, uint256 amount);
    event TokenVestingRevoked(address token);

    function setUp() public {
        // Deploy token
        token = new MockERC20("Test Token", "TEST", 10_000_000 * 10**18);
        
        // Transfer tokens to owner for testing
        token.transfer(owner, 2_000_000 * 10**18);
        
        // Set up owner
        vm.prank(owner);
        vesting = new TokenVesting(
            beneficiary,
            address(token),
            TOTAL_AMOUNT,
            true // revocable
        );
        
        // Transfer tokens to vesting contract
        vm.prank(owner);
        token.transfer(address(vesting), TOTAL_AMOUNT);
    }
    // wake-disable-next-line
    function testInitialState() public {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.totalAmount(), TOTAL_AMOUNT);
        assertEq(vesting.released(), 0);
        assertEq(vesting.revocable(), true);
        assertEq(vesting.revoked(), false);
        
        // Check cliff and duration
        assertEq(vesting.cliff(), block.timestamp + CLIFF_DURATION);
        assertEq(vesting.duration(), VESTING_DURATION);
        
        // Check token balance
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT);
    }

    function testCannotReleaseBeforeCliff() public {
        // Try to release before cliff
        vm.expectRevert("TokenVesting: no tokens are due");
        vesting.release();
        
        // Fast forward to just before cliff
        vm.warp(block.timestamp + CLIFF_DURATION - 1);
        
        vm.expectRevert("TokenVesting: no tokens are due");
        vesting.release();
        
        assertEq(vesting.releasableAmount(), 0);
        assertEq(vesting.vestedAmount(), 0);
    }

    function testReleaseAtCliff() public {
        // Fast forward to cliff
        vm.warp(block.timestamp + CLIFF_DURATION);
        
        // At cliff, no tokens should be releasable yet (linear vesting starts after cliff)
        assertEq(vesting.releasableAmount(), 0);
        assertEq(vesting.vestedAmount(), 0);
    }

    function testLinearVestingAfterCliff() public {
        uint256 startTime = block.timestamp;
        
        // Fast forward to 1 month after cliff (1/24 of vesting period)
        uint256 oneMonthAfterCliff = startTime + CLIFF_DURATION + 30 days;
        vm.warp(oneMonthAfterCliff);
        
        uint256 expectedVested = (TOTAL_AMOUNT * 30 days) / VESTING_DURATION;
        uint256 actualVested = vesting.vestedAmount();
        
        // Allow for small rounding differences
        assertApproxEqRel(actualVested, expectedVested, 0.01e18); // 1% tolerance
        
        // Test release
        uint256 releasableAmount = vesting.releasableAmount();
        assertEq(releasableAmount, actualVested);
        
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(address(token), releasableAmount);
        
        vesting.release();
        
        assertEq(vesting.released(), releasableAmount);
        assertEq(token.balanceOf(beneficiary), releasableAmount);
    }

    function testMonthlyReleases() public {
        uint256 startTime = block.timestamp;
        
        // Test releases over 24 months after cliff
        for (uint256 month = 1; month <= 24; month++) {
            uint256 timeAfterCliff = startTime + CLIFF_DURATION + (month * 30 days);
            vm.warp(timeAfterCliff);
            
            uint256 expectedTotalVested = (TOTAL_AMOUNT * month * 30 days) / VESTING_DURATION;
            if (expectedTotalVested > TOTAL_AMOUNT) {
                expectedTotalVested = TOTAL_AMOUNT;
            }
            
            uint256 actualVested = vesting.vestedAmount();
            uint256 releasableAmount = vesting.releasableAmount();
            
            // Verify vested amount
            assertApproxEqRel(actualVested, expectedTotalVested, 0.01e18);
            
            // Release tokens
            if (releasableAmount > 0) {
                uint256 balanceBefore = token.balanceOf(beneficiary);
                vesting.release();
                uint256 balanceAfter = token.balanceOf(beneficiary);
                
                assertEq(balanceAfter - balanceBefore, releasableAmount);
            }
        }
    }

    function testFullVestingAfter36Months() public {
        // Fast forward to end of vesting period (12 months cliff + 24 months vesting)
        vm.warp(block.timestamp + CLIFF_DURATION + VESTING_DURATION);
        
        assertEq(vesting.vestedAmount(), TOTAL_AMOUNT);
        assertEq(vesting.releasableAmount(), TOTAL_AMOUNT);
        
        // Release all tokens
        vesting.release();
        
        assertEq(vesting.released(), TOTAL_AMOUNT);
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
        assertEq(token.balanceOf(address(vesting)), 0);
        
        // No more tokens to release
        assertEq(vesting.releasableAmount(), 0);
    }

    function testRevoke() public {
        // Fast forward to middle of vesting period
        vm.warp(block.timestamp + CLIFF_DURATION + VESTING_DURATION / 2);
        
        uint256 vestedAmount = vesting.vestedAmount();
        uint256 contractBalance = token.balanceOf(address(vesting));
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        vm.expectEmit(true, true, true, true);
        emit TokenVestingRevoked(address(token));
        
        vm.prank(owner);
        vesting.revoke();
        
        assertTrue(vesting.revoked());
        
        // Owner should receive unvested tokens
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        uint256 expectedRefund = contractBalance - vestedAmount;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedRefund);
        
        // Beneficiary can still release vested tokens
        vesting.release();
        assertEq(token.balanceOf(beneficiary), vestedAmount);
    }

    function testCannotRevokeIfNotRevocable() public {
        // Deploy non-revocable vesting
        vm.prank(owner);
        TokenVesting nonRevocableVesting = new TokenVesting(
            beneficiary,
            address(token),
            TOTAL_AMOUNT,
            false // not revocable
        );
        
        vm.prank(owner);
        vm.expectRevert("TokenVesting: cannot revoke");
        nonRevocableVesting.revoke();
    }

    function testCannotRevokeIfAlreadyRevoked() public {
        vm.prank(owner);
        vesting.revoke();
        
        vm.prank(owner);
        vm.expectRevert("TokenVesting: token already revoked");
        vesting.revoke();
    }

    function testOnlyOwnerCanRevoke() public {
        vm.prank(beneficiary);
        vm.expectRevert();
        vesting.revoke();
    }

    function testMultipleReleases() public {
        uint256 startTime = block.timestamp;
        
        // Fast forward to 6 months after cliff
        vm.warp(startTime + CLIFF_DURATION + 180 days);
        
        uint256 firstRelease = vesting.releasableAmount();
        vesting.release();
        
        // Fast forward another 6 months
        vm.warp(startTime + CLIFF_DURATION + 360 days);
        
        uint256 secondRelease = vesting.releasableAmount();
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), firstRelease + secondRelease);
        assertEq(vesting.released(), firstRelease + secondRelease);
    }

    function testVestingScheduleAccuracy() public {
        uint256 startTime = block.timestamp;
        
        // Test at various points during vesting
        uint256[] memory testPoints = new uint256[](5);
        testPoints[0] = startTime + CLIFF_DURATION + 73 days;  // ~10% through vesting
        testPoints[1] = startTime + CLIFF_DURATION + 182 days; // ~25% through vesting
        testPoints[2] = startTime + CLIFF_DURATION + 365 days; // ~50% through vesting
        testPoints[3] = startTime + CLIFF_DURATION + 547 days; // ~75% through vesting
        testPoints[4] = startTime + CLIFF_DURATION + 730 days; // 100% through vesting
        
        uint256[] memory expectedPercentages = new uint256[](5);
        expectedPercentages[0] = 10;
        expectedPercentages[1] = 25;
        expectedPercentages[2] = 50;
        expectedPercentages[3] = 75;
        expectedPercentages[4] = 100;
        
        for (uint256 i = 0; i < testPoints.length; i++) {
            vm.warp(testPoints[i]);
            
            uint256 vestedAmount = vesting.vestedAmount();
            uint256 expectedAmount = (TOTAL_AMOUNT * expectedPercentages[i]) / 100;
            
            // Allow for 2% tolerance due to time approximations
            assertApproxEqRel(vestedAmount, expectedAmount, 0.02e18);
        }
    }
}