// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/dao/VotingToken.sol";
import "../src/dao/Bank.sol";
import "../src/dao/Gov.sol";
import "../src/MockERC20.sol";

contract DAOTest is Test {
    VotingToken public token;
    Bank public bank;
    Gov public gov;
    MockERC20 public mockToken;
    
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000000e18;
    uint256 public constant PROPOSAL_THRESHOLD = 100000e18;
    
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );
    
    event ProposalExecuted(uint256 proposalId);
    
    function setUp() public {
        // 部署合约
        token = new VotingToken("DAO Token", "DAO", INITIAL_SUPPLY);
        bank = new Bank();
        gov = new Gov(address(token), address(bank));
        mockToken = new MockERC20("Mock Token", "MOCK", 18);
        
        // 将Bank的所有权转移给Gov合约
        bank.transferOwnership(address(gov));
        
        // 分发代币
        token.transfer(alice, 300000e18);
        token.transfer(bob, 200000e18);
        token.transfer(charlie, 100000e18);
        
        // 用户委托投票权给自己
        vm.prank(alice);
        token.delegate(alice);
        
        vm.prank(bob);
        token.delegate(bob);
        
        vm.prank(charlie);
        token.delegate(charlie);
        
        // 等待一个区块以确保投票权生效
        vm.roll(block.number + 1);
        
        // 给Bank存入一些资金
        mockToken.mint(address(bank), 1000000e18);
        vm.deal(address(bank), 100 ether);
    }
    
    function testTokenVoting() public {
        // 测试投票权委托
        assertEq(token.getVotes(alice), 300000e18);
        assertEq(token.getVotes(bob), 200000e18);
        assertEq(token.getVotes(charlie), 100000e18);
        
        // 测试重新委托
        vm.prank(charlie);
        token.delegate(alice);
        
        assertEq(token.getVotes(alice), 400000e18);
        assertEq(token.getVotes(charlie), 0);
    }
    
    function testBankDepositsAndWithdrawals() public {
        // 测试ETH存款
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        bank.depositEther{value: 5 ether}();
        
        assertEq(bank.getEtherBalance(), 105 ether);
        
        // 测试ERC20存款
        mockToken.mint(alice, 1000e18);
        vm.startPrank(alice);
        mockToken.approve(address(bank), 1000e18);
        bank.depositToken(address(mockToken), 1000e18);
        vm.stopPrank();
        
        assertEq(bank.getTokenBalance(address(mockToken)), 1001000e18);
    }
    
    function testProposalCreation() public {
        // 准备提案数据
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdraw(address,address,uint256)",
            address(mockToken),
            alice,
            100000e18
        );
        
        // Alice创建提案
        vm.prank(alice);
        uint256 proposalId = gov.propose(
            targets,
            values,
            calldatas,
            "Withdraw 100,000 tokens to Alice"
        );
        
        assertEq(proposalId, 1);
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Pending));
    }
    
    function testProposalThreshold() public {
        // 创建一个新用户，没有足够的代币创建提案
        address newUser = address(0x999);
        token.transfer(newUser, 50000e18); // 少于100000的门槛
        
        vm.prank(newUser);
        token.delegate(newUser);
        
        vm.roll(block.number + 1); // 等待投票权生效
        
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("withdraw(address,address,uint256)", address(mockToken), newUser, 1000e18);
        
        vm.prank(newUser);
        vm.expectRevert(Gov.InsufficientProposalThreshold.selector);
        gov.propose(targets, values, calldatas, "Should fail");
    }
    
    function testVotingProcess() public {
        // 创建提案
        uint256 proposalId = _createSampleProposal();
        
        // 等待投票开始
        vm.roll(block.number + 2);
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Active));
        
        // Alice投赞成票
        vm.prank(alice);
        gov.castVoteWithReason(proposalId, 1, "I support this proposal");
        
        // Bob投反对票
        vm.prank(bob);
        gov.castVote(proposalId, 0);
        
        // 检查投票结果
        (,,,, uint256 forVotes, uint256 againstVotes,,,,,) = gov.proposals(proposalId);
        assertEq(forVotes, 300000e18);
        assertEq(againstVotes, 200000e18);
        
        // 检查投票记录
        Gov.Receipt memory aliceReceipt = gov.getReceipt(proposalId, alice);
        assertTrue(aliceReceipt.hasVoted);
        assertEq(aliceReceipt.support, 1);
        assertEq(aliceReceipt.votes, 300000e18);
    }
    
    function testProposalExecution() public {
        uint256 proposalId = _createSampleProposal();
        
        // 等待投票开始并进行投票
        vm.roll(block.number + 2);
        
        vm.prank(alice);
        gov.castVote(proposalId, 1); // 支持
        
        vm.prank(bob);
        gov.castVote(proposalId, 1); // 支持
        
        // 等待投票结束
        vm.roll(block.number + 17280);
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Succeeded));
        
        // 将提案加入执行队列
        gov.queue(proposalId);
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Queued));
        
        // 等待时间锁过期
        vm.warp(block.timestamp + 2 days + 1);
        
        // 记录执行前的余额
        uint256 aliceBalanceBefore = mockToken.balanceOf(alice);
        uint256 bankBalanceBefore = bank.getTokenBalance(address(mockToken));
        
        // 执行提案
        gov.execute(proposalId);
        
        // 检查执行结果
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Executed));
        assertEq(mockToken.balanceOf(alice), aliceBalanceBefore + 100000e18);
        assertEq(bank.getTokenBalance(address(mockToken)), bankBalanceBefore - 100000e18);
    }
    
    function testProposalCancellation() public {
        uint256 proposalId = _createSampleProposal();
        
        // Alice取消自己的提案
        vm.prank(alice);
        gov.cancel(proposalId);
        
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Canceled));
    }
    
    function testQuorumRequirement() public {
        uint256 proposalId = _createSampleProposal();
        
        // 等待投票开始
        vm.roll(block.number + 2);
        
        // 只有Charlie投票（不足法定人数，需要4%即40000代币，Charlie只有100000代币）
        vm.prank(charlie);
        gov.castVote(proposalId, 1);
        
        // 等待投票结束
        vm.roll(block.number + 17280);
        
        // 检查法定人数
        uint256 quorum = gov.quorum(proposalId);
        // 总供应量1000000 * 4% = 40000
        assertEq(quorum, 40000e18);
        
        // Charlie的投票权是100000，大于法定人数，所以提案应该通过
        assertEq(uint256(gov.state(proposalId)), uint256(Gov.ProposalState.Succeeded));
    }
    
    function testMultipleProposals() public {
        // 创建多个提案
        uint256 proposalId1 = _createSampleProposal();
        
        address[] memory targets2 = new address[](1);
        uint256[] memory values2 = new uint256[](1);
        bytes[] memory calldatas2 = new bytes[](1);
        
        targets2[0] = address(bank);
        values2[0] = 0;
        calldatas2[0] = abi.encodeWithSignature(
            "withdrawEther(address,uint256)",
            payable(bob),
            10 ether
        );
        
        vm.prank(alice);
        uint256 proposalId2 = gov.propose(
            targets2,
            values2,
            calldatas2,
            "Withdraw 10 ETH to Bob"
        );
        
        assertEq(proposalId1, 1);
        assertEq(proposalId2, 2);
        assertEq(gov.proposalCount(), 2);
    }
    
    function testBatchWithdraw() public {
        // 创建批量提取提案
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        address[] memory tokens = new address[](2);
        tokens[0] = address(mockToken);
        tokens[1] = address(mockToken);
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50000e18;
        amounts[1] = 30000e18;
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "batchWithdraw(address[],address,uint256[])",
            tokens,
            alice,
            amounts
        );
        
        vm.prank(alice);
        uint256 proposalId = gov.propose(
            targets,
            values,
            calldatas,
            "Batch withdraw tokens"
        );
        
        // 投票并执行
        vm.roll(block.number + 2);
        
        vm.prank(alice);
        gov.castVote(proposalId, 1);
        
        vm.prank(bob);
        gov.castVote(proposalId, 1);
        
        vm.roll(block.number + 17280);
        gov.queue(proposalId);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        uint256 aliceBalanceBefore = mockToken.balanceOf(alice);
        gov.execute(proposalId);
        
        // 批量提取会执行两次，总共80000代币
        assertEq(mockToken.balanceOf(alice), aliceBalanceBefore + 80000e18);
    }
    
    function testEmergencyWithdraw() public {
        // 创建紧急提取提案
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "emergencyWithdraw(address,address)",
            address(0), // ETH
            payable(alice)
        );
        
        vm.prank(alice);
        uint256 proposalId = gov.propose(
            targets,
            values,
            calldatas,
            "Emergency withdraw all ETH"
        );
        
        // 投票并执行
        vm.roll(block.number + 2);
        
        vm.prank(alice);
        gov.castVote(proposalId, 1);
        
        vm.prank(bob);
        gov.castVote(proposalId, 1);
        
        vm.roll(block.number + 17280);
        gov.queue(proposalId);
        
        vm.warp(block.timestamp + 2 days + 1);
        
        uint256 aliceBalanceBefore = alice.balance;
        uint256 bankBalanceBefore = bank.getEtherBalance();
        
        gov.execute(proposalId);
        
        assertEq(alice.balance, aliceBalanceBefore + bankBalanceBefore);
        assertEq(bank.getEtherBalance(), 0);
    }
    
    function test_RevertWhen_UnauthorizedWithdraw() public {
        // 直接调用Bank的withdraw应该失败
        vm.prank(alice);
        vm.expectRevert();
        bank.withdraw(address(mockToken), alice, 1000e18);
    }
    
    function test_RevertWhen_DoubleVoting() public {
        uint256 proposalId = _createSampleProposal();
        
        vm.roll(block.number + 2);
        
        vm.prank(alice);
        gov.castVote(proposalId, 1);
        
        // 尝试再次投票应该失败
        vm.prank(alice);
        vm.expectRevert();
        gov.castVote(proposalId, 0);
    }
    
    function test_RevertWhen_ExecuteWithoutTimelock() public {
        uint256 proposalId = _createSampleProposal();
        
        vm.roll(block.number + 2);
        
        vm.prank(alice);
        gov.castVote(proposalId, 1);
        
        vm.prank(bob);
        gov.castVote(proposalId, 1);
        
        vm.roll(block.number + 17280);
        gov.queue(proposalId);
        
        // 尝试在时间锁到期前执行应该失败
        vm.expectRevert();
        gov.execute(proposalId);
    }
    
    // 辅助函数
    function _createSampleProposal() internal returns (uint256) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdraw(address,address,uint256)",
            address(mockToken),
            alice,
            100000e18
        );
        
        vm.prank(alice);
        return gov.propose(
            targets,
            values,
            calldatas,
            "Withdraw 100,000 tokens to Alice"
        );
    }
}