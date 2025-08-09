// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./uniswapv2/interfaces/IWETH.sol";

/**
 * @title WETH
 * @dev Wrapped Ether implementation
 * 实现了标准的WETH功能，支持ETH的包装和解包装
 */
contract WETH is ERC20, IWETH {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() ERC20("Wrapped Ether", "WETH") {}

    /**
     * @dev 接收ETH的回调函数，自动包装为WETH
     */
    receive() external payable {
        deposit();
    }

    /**
     * @dev 存入ETH并获得WETH
     */
    function deposit() public payable override {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 提取WETH并获得ETH
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) public override {
        require(balanceOf(msg.sender) >= amount, "WETH: insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev 重写transfer函数以符合IWETH接口
     */
    function transfer(address to, uint256 value) public override(ERC20, IWETH) returns (bool) {
        return super.transfer(to, value);
    }
}