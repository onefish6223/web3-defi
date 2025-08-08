// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IWETH
 * @dev 包装ETH接口
 * 定义了WETH合约的标准接口
 */
interface IWETH {
    /**
     * @dev 存入ETH并获得WETH
     */
    function deposit() external payable;

    /**
     * @dev 转账WETH
     * @param to 接收地址
     * @param value 转账数量
     * @return 是否成功
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev 提取WETH并获得ETH
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external;
}