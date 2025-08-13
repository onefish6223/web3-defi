// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeflationaryRebaseToken
 * @dev 通缩型 Rebase Token 实现
 * 起始发行量为 1 亿，每年在上一年的发行量基础上下降 1%
 */
contract DeflationaryRebaseToken is ERC20, Ownable {
    // 初始总供应量：1亿 tokens
    uint256 private constant INITIAL_SUPPLY = 100_000_000 * 10**18;
    
    // 每年通缩率：1% (即保留99%)
    uint256 private constant DEFLATION_RATE = 99; // 99%
    uint256 private constant RATE_PRECISION = 100;
    
    // 当前的 rebase 倍数，初始为 1e18 (表示 1.0)
    uint256 private _rebaseMultiplier;
    
    // 用户的原始余额（不受 rebase 影响）
    mapping(address => uint256) private _rawBalances;
    
    // 总的原始供应量
    uint256 private _rawTotalSupply;
    
    // 上次 rebase 的时间戳
    uint256 public lastRebaseTime;
    
    // rebase 间隔（1年 = 365天）
    uint256 public constant REBASE_INTERVAL = 365 days;
    
    event Rebase(uint256 newMultiplier, uint256 newTotalSupply);
    
    constructor() ERC20("Deflationary Rebase Token", "DRT") Ownable(msg.sender) {
        _rebaseMultiplier = 1e18; // 初始倍数为 1.0
        _rawTotalSupply = INITIAL_SUPPLY;
        _rawBalances[msg.sender] = INITIAL_SUPPLY;
        lastRebaseTime = block.timestamp;
        
        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
    }
    
    /**
     * @dev 执行 rebase 操作，每年可调用一次
     */
    function rebase() external {
        require(
            block.timestamp >= lastRebaseTime + REBASE_INTERVAL,
            "Rebase: Too early to rebase"
        );
        
        // 计算新的倍数：当前倍数 * 0.99
        _rebaseMultiplier = (_rebaseMultiplier * DEFLATION_RATE) / RATE_PRECISION;
        
        // 更新最后 rebase 时间
        lastRebaseTime = block.timestamp;
        
        emit Rebase(_rebaseMultiplier, totalSupply());
    }
    
    /**
     * @dev 返回当前总供应量（受 rebase 影响）
     */
    function totalSupply() public view override returns (uint256) {
        return (_rawTotalSupply * _rebaseMultiplier) / 1e18;
    }
    
    /**
     * @dev 返回用户余额（受 rebase 影响）
     */
    function balanceOf(address account) public view override returns (uint256) {
        return (_rawBalances[account] * _rebaseMultiplier) / 1e18;
    }
    
    /**
     * @dev 获取用户原始余额（不受 rebase 影响）
     */
    function rawBalanceOf(address account) external view returns (uint256) {
        return _rawBalances[account];
    }
    
    /**
     * @dev 获取当前 rebase 倍数
     */
    function getRebaseMultiplier() external view returns (uint256) {
        return _rebaseMultiplier;
    }
    
    /**
     * @dev 转账功能
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transferRaw(owner, to, amount);
        return true;
    }
    
    /**
     * @dev 授权转账功能
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferRaw(from, to, amount);
        return true;
    }
    
    /**
     * @dev 内部转账函数，处理原始余额
     */
    function _transferRaw(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        // 计算对应的原始金额
        uint256 rawAmount = (amount * 1e18) / _rebaseMultiplier;
        
        unchecked {
            _rawBalances[from] -= rawAmount;
        }
        _rawBalances[to] += rawAmount;
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev 铸造新代币（仅限所有者）
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "ERC20: mint to the zero address");
        
        // 计算对应的原始金额
        uint256 rawAmount = (amount * 1e18) / _rebaseMultiplier;
        
        _rawTotalSupply += rawAmount;
        _rawBalances[to] += rawAmount;
        
        emit Transfer(address(0), to, amount);
    }
    
    /**
     * @dev 销毁代币
     */
    function burn(uint256 amount) external {
        address account = _msgSender();
        
        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        
        // 计算对应的原始金额
        uint256 rawAmount = (amount * 1e18) / _rebaseMultiplier;
        
        unchecked {
            _rawBalances[account] -= rawAmount;
            _rawTotalSupply -= rawAmount;
        }
        
        emit Transfer(account, address(0), amount);
    }
    
    /**
     * @dev 手动触发 rebase（仅限所有者，用于测试）
     */
    function forceRebase() external onlyOwner {
        _rebaseMultiplier = (_rebaseMultiplier * DEFLATION_RATE) / RATE_PRECISION;
        lastRebaseTime = block.timestamp;
        
        emit Rebase(_rebaseMultiplier, totalSupply());
    }
    
    /**
     * @dev 检查是否可以进行 rebase
     */
    function canRebase() external view returns (bool) {
        return block.timestamp >= lastRebaseTime + REBASE_INTERVAL;
    }
    
    /**
     * @dev 获取距离下次 rebase 的时间
     */
    function timeUntilNextRebase() external view returns (uint256) {
        if (block.timestamp >= lastRebaseTime + REBASE_INTERVAL) {
            return 0;
        }
        return (lastRebaseTime + REBASE_INTERVAL) - block.timestamp;
    }
}