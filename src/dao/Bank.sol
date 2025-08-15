// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Bank
 * @dev 银行合约，管理资金的存取
 * 只有管理员（通常是治理合约）可以提取资金
 */
contract Bank is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 事件
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed admin, address indexed token, address indexed to, uint256 amount);
    event EtherDeposit(address indexed user, uint256 amount);
    event EtherWithdraw(address indexed admin, address indexed to, uint256 amount);

    // 错误
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAmount();
    error ZeroAddress();

    constructor() Ownable(msg.sender) {}

    /**
     * @dev 接收ETH存款
     */
    receive() external payable {
        if (msg.value > 0) {
            emit EtherDeposit(msg.sender, msg.value);
        }
    }

    /**
     * @dev 存入ERC20代币
     * @param token 代币合约地址
     * @param amount 存入数量
     */
    function depositToken(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (token == address(0)) revert ZeroAddress();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, token, amount);
    }

    /**
     * @dev 存入ETH
     */
    function depositEther() external payable {
        if (msg.value == 0) revert ZeroAmount();
        emit EtherDeposit(msg.sender, msg.value);
    }

    /**
     * @dev 提取ERC20代币（仅管理员）
     * @param token 代币合约地址
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdraw(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();

        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        tokenContract.safeTransfer(to, amount);
        emit Withdraw(msg.sender, token, to, amount);
    }

    /**
     * @dev 提取ETH（仅管理员）
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawEther(address payable to, uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit EtherWithdraw(msg.sender, to, amount);
    }

    /**
     * @dev 批量提取多种代币（仅管理员）
     * @param tokens 代币合约地址数组
     * @param to 接收地址
     * @param amounts 提取数量数组
     */
    function batchWithdraw(
        address[] calldata tokens,
        address to,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        if (tokens.length != amounts.length) revert("Array length mismatch");
        if (to == address(0)) revert ZeroAddress();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0 && tokens[i] != address(0)) {
                IERC20 tokenContract = IERC20(tokens[i]);
                uint256 balance = tokenContract.balanceOf(address(this));
                if (balance >= amounts[i]) {
                    tokenContract.safeTransfer(to, amounts[i]);
                    emit Withdraw(msg.sender, tokens[i], to, amounts[i]);
                }
            }
        }
    }

    /**
     * @dev 紧急提取所有资金（仅管理员）
     * @param token 代币合约地址，address(0)表示ETH
     * @param to 接收地址
     */
    function emergencyWithdraw(address token, address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();

        if (token == address(0)) {
            // 提取所有ETH
            uint256 balance = address(this).balance;
            if (balance > 0) {
                (bool success, ) = to.call{value: balance}("");
                if (!success) revert TransferFailed();
                emit EtherWithdraw(msg.sender, to, balance);
            }
        } else {
            // 提取所有指定代币
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            if (balance > 0) {
                tokenContract.safeTransfer(to, balance);
                emit Withdraw(msg.sender, token, to, balance);
            }
        }
    }

    /**
     * @dev 获取ERC20代币余额
     * @param token 代币合约地址
     * @return 余额
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev 获取ETH余额
     * @return 余额
     */
    function getEtherBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 获取多种代币余额
     * @param tokens 代币合约地址数组
     * @return balances 余额数组
     */
    function getBatchTokenBalances(address[] calldata tokens) external view returns (uint256[] memory balances) {
        balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = IERC20(tokens[i]).balanceOf(address(this));
        }
    }

    /**
     * @dev 检查是否有足够余额
     * @param token 代币合约地址，address(0)表示ETH
     * @param amount 检查数量
     * @return 是否有足够余额
     */
    function hasSufficientBalance(address token, uint256 amount) external view returns (bool) {
        if (token == address(0)) {
            return address(this).balance >= amount;
        } else {
            return IERC20(token).balanceOf(address(this)) >= amount;
        }
    }
}