// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IUniswapV2Callee
 * @dev UniswapV2回调接口
 * 实现此接口的合约可以接收flash swap回调
 */
interface IUniswapV2Callee {
    /**
     * @dev UniswapV2回调函数
     * 当调用swap函数并传入非空data参数时，会调用此函数
     * 实现此接口的合约可以在回调中执行任意逻辑，但必须确保在函数结束前
     * 向交易对合约支付足够的代币以满足恒定乘积公式
     * 
     * @param sender 调用swap函数的地址
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param data 传递给swap函数的数据
     */
    function uniswapV2Call(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}