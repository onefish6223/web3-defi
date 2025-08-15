// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingToken
 * @dev ERC20代币合约，支持投票功能
 * 每个代币持有者可以将其投票权委托给其他地址
 */
 //wake-disable
contract VotingToken is ERC20, Ownable {
    // 检查点结构，用于记录历史投票权
    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    // 每个地址的投票权检查点
    mapping(address => Checkpoint[]) private _checkpoints;

    // 每个地址的委托对象
    mapping(address => address) private _delegates;

    // 总投票权检查点
    Checkpoint[] private _totalSupplyCheckpoints;

    // 事件
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev 铸造新代币（仅所有者）
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 获取当前投票权
     */
    function getVotes(address account) external view returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev 获取历史投票权
     */
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "VotingToken: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /**
     * @dev 获取历史总供应量
     */
    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "VotingToken: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    /**
     * @dev 获取委托对象
     */
    function delegates(address account) external view returns (address) {
        return _delegates[account];
    }

    /**
     * @dev 委托投票权
     */
    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }

    /**
     * @dev 通过签名委托投票权
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 简化实现，实际项目中需要完整的EIP-712签名验证
        require(block.timestamp <= expiry, "VotingToken: signature expired");
        // 这里省略签名验证逻辑
        _delegate(delegatee, delegatee);
    }

    /**
     * @dev 内部委托函数
     */
    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    /**
     * @dev 转移投票权
     */
    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) internal {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_checkpoints[src], _subtract, amount);
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(_checkpoints[dst], _add, amount);
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    /**
     * @dev 重写转账函数以更新投票权
     */
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        if (from == address(0)) {
            // 铸造
            _writeCheckpoint(_totalSupplyCheckpoints, _add, value);
        } else {
            // 转账或销毁
            _moveVotingPower(_delegates[from], _delegates[to], value);
        }

        if (to == address(0)) {
            // 销毁
            _writeCheckpoint(_totalSupplyCheckpoints, _subtract, value);
        }
    }

    /**
     * @dev 写入检查点
     */
    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(Checkpoint({
                fromBlock: SafeCast.toUint32(block.number),
                votes: SafeCast.toUint224(newWeight)
            }));
        }
    }

    /**
     * @dev 加法操作
     */
    function _add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev 减法操作
     */
    function _subtract(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev 查找检查点
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) internal view returns (uint256) {
        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (ckpts[mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high == 0 ? 0 : ckpts[high - 1].votes;
    }
}

// SafeCast库的简化版本
library SafeCast {
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }
}