// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IUniswapV2Factory
 * @dev UniswapV2工厂合约接口
 * 工厂合约负责创建和管理所有的交易对合约
 */
interface IUniswapV2Factory {
    /**
     * @dev 当创建新的交易对时触发的事件
     * @param token0 交易对中的第一个代币地址（按字典序排序后的较小地址）
     * @param token1 交易对中的第二个代币地址（按字典序排序后的较大地址）
     * @param pair 新创建的交易对合约地址
     * @param allPairsLength 当前所有交易对的总数量
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 allPairsLength);

    /**
     * @dev 获取协议手续费接收地址
     * @return 协议手续费接收地址，如果为零地址则表示协议手续费关闭
     */
    function feeTo() external view returns (address);

    /**
     * @dev 获取有权设置协议手续费接收地址的管理员地址
     * @return 管理员地址
     */
    function feeToSetter() external view returns (address);

    /**
     * @dev 根据两个代币地址获取对应的交易对合约地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 交易对合约地址，如果不存在则返回零地址
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    /**
     * @dev 根据索引获取交易对合约地址
     * @param index 交易对在数组中的索引
     * @return pair 交易对合约地址
     */
    function allPairs(uint256 index) external view returns (address pair);

    /**
     * @dev 获取所有交易对的总数量
     * @return 交易对总数量
     */
    function allPairsLength() external view returns (uint256);

    /**
     * @dev 创建新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 新创建的交易对合约地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /**
     * @dev 设置协议手续费接收地址（只有管理员可以调用）
     * @param _feeTo 新的协议手续费接收地址
     */
    function setFeeTo(address _feeTo) external;

    /**
     * @dev 设置新的管理员地址（只有当前管理员可以调用）
     * @param _feeToSetter 新的管理员地址
     */
    function setFeeToSetter(address _feeToSetter) external;
}