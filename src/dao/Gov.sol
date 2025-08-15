// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VotingToken.sol";
import "./Bank.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Gov
 * @dev 治理合约，管理提案的创建、投票和执行
 * 作为Bank合约的管理员，通过投票决定资金使用
 */
 //wake-disable
contract Gov is ReentrancyGuard {
    // 提案状态枚举
    enum ProposalState {
        Pending,    // 待投票
        Active,     // 投票中
        Canceled,   // 已取消
        Defeated,   // 被否决
        Succeeded,  // 通过
        Queued,     // 排队等待执行
        Expired,    // 已过期
        Executed    // 已执行
    }

    // 提案结构
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        string description;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 eta; // 执行时间
    }

    // 投票记录
    struct Receipt {
        bool hasVoted;
        uint8 support; // 0=反对, 1=支持, 2=弃权
        uint256 votes;
    }

    // 状态变量
    VotingToken public immutable token;
    Bank public immutable bank;
    
    uint256 public proposalCount;
    uint256 public votingDelay = 1; // 提案创建后多少区块开始投票
    uint256 public votingPeriod = 17280; // 投票持续区块数（约3天）
    uint256 public proposalThreshold = 100000e18; // 创建提案所需的最小代币数量
    uint256 public quorumNumerator = 4; // 法定人数分子（4%）
    uint256 public timelock = 2 days; // 执行延迟时间
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    
    // 事件
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
    
    event ProposalCanceled(uint256 proposalId);
    event ProposalQueued(uint256 proposalId, uint256 eta);
    event ProposalExecuted(uint256 proposalId);
    
    // 错误
    error InsufficientProposalThreshold();
    error InvalidProposalLength();
    error ProposalNotActive();
    error AlreadyVoted();
    error ProposalNotSucceeded();
    error ProposalNotQueued();
    error TimelockNotMet();
    error ExecutionFailed();
    error OnlyProposer();
    error ProposalNotPending();

    constructor(address _token, address _bank) {
        token = VotingToken(_token);
        bank = Bank(payable(_bank));
    }

    /**
     * @dev 创建提案
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        // 检查提案者是否有足够的代币
        if (token.getPastVotes(msg.sender, block.number - 1) < proposalThreshold) {
            revert InsufficientProposalThreshold();
        }
        
        // 检查数组长度
        if (targets.length != values.length || targets.length != calldatas.length) {
            revert InvalidProposalLength();
        }
        
        uint256 proposalId = ++proposalCount;
        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            canceled: false,
            executed: false,
            description: description,
            targets: targets,
            values: values,
            calldatas: calldatas,
            eta: 0
        });
        
        string[] memory signatures = new string[](targets.length);
        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        
        return proposalId;
    }

    /**
     * @dev 投票
     * @param proposalId 提案ID
     * @param support 投票类型：0=反对, 1=支持, 2=弃权
     */
    function castVote(uint256 proposalId, uint8 support) external {
        return _castVote(proposalId, msg.sender, support, "");
    }

    /**
     * @dev 带理由投票
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        return _castVote(proposalId, msg.sender, support, reason);
    }

    /**
     * @dev 内部投票函数
     */
    function _castVote(
        uint256 proposalId,
        address voter,
        uint8 support,
        string memory reason
    ) internal {
        if (state(proposalId) != ProposalState.Active) {
            revert ProposalNotActive();
        }
        
        Receipt storage receipt = receipts[proposalId][voter];
        if (receipt.hasVoted) {
            revert AlreadyVoted();
        }
        
        uint256 weight = token.getPastVotes(voter, proposals[proposalId].startBlock);
        
        if (support == 0) {
            proposals[proposalId].againstVotes += weight;
        } else if (support == 1) {
            proposals[proposalId].forVotes += weight;
        } else if (support == 2) {
            proposals[proposalId].abstainVotes += weight;
        }
        
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = weight;
        
        emit VoteCast(voter, proposalId, support, weight, reason);
    }

    /**
     * @dev 将通过的提案加入执行队列
     */
    function queue(uint256 proposalId) external {
        if (state(proposalId) != ProposalState.Succeeded) {
            revert ProposalNotSucceeded();
        }
        
        uint256 eta = block.timestamp + timelock;
        proposals[proposalId].eta = eta;
        
        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @dev 执行提案
     */
    function execute(uint256 proposalId) external payable nonReentrant {
        if (state(proposalId) != ProposalState.Queued) {
            revert ProposalNotQueued();
        }
        
        if (block.timestamp < proposals[proposalId].eta) {
            revert TimelockNotMet();
        }
        
        // 先更新状态，防止重入攻击
        proposals[proposalId].executed = true;
        
        Proposal storage proposal = proposals[proposalId];
        
        // 执行所有调用
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            //wake-disable
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                proposal.calldatas[i]
            );
            if (!success) {
                // 如果执行失败，恢复状态并抛出错误
                proposals[proposalId].executed = false;
                revert ExecutionFailed();
            }
        }
        
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev 取消提案（仅提案者）
     */
    function cancel(uint256 proposalId) external {
        if (proposals[proposalId].proposer != msg.sender) {
            revert OnlyProposer();
        }
        
        if (state(proposalId) != ProposalState.Pending && state(proposalId) != ProposalState.Active) {
            revert ProposalNotPending();
        }
        
        proposals[proposalId].canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @dev 获取提案状态
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorum(proposalId)) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @dev 计算法定人数
     */
    function quorum(uint256 proposalId) public view returns (uint256) {
        return (token.getPastTotalSupply(proposals[proposalId].startBlock) * quorumNumerator) / 100;
    }

    /**
     * @dev 获取提案详情
     */
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.calldatas);
    }

    /**
     * @dev 获取投票记录
     */
    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (Receipt memory)
    {
        return receipts[proposalId][voter];
    }

    /**
     * @dev 设置投票参数（仅通过治理）
     */
    function setVotingDelay(uint256 newVotingDelay) external {
        require(msg.sender == address(this), "Only governance");
        votingDelay = newVotingDelay;
    }

    function setVotingPeriod(uint256 newVotingPeriod) external {
        require(msg.sender == address(this), "Only governance");
        votingPeriod = newVotingPeriod;
    }

    function setProposalThreshold(uint256 newProposalThreshold) external {
        require(msg.sender == address(this), "Only governance");
        proposalThreshold = newProposalThreshold;
    }

    function setQuorumNumerator(uint256 newQuorumNumerator) external {
        require(msg.sender == address(this), "Only governance");
        require(newQuorumNumerator <= 100, "Invalid quorum");
        quorumNumerator = newQuorumNumerator;
    }
}