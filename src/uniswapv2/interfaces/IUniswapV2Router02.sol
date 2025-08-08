// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import './IUniswapV2Router01.sol';

/**
 * @title IUniswapV2Router02
 * @dev UniswapV2路由器接口V2
 * 继承自IUniswapV2Router01，添加了支持手续费转移的功能
 */
interface IUniswapV2Router02 is IUniswapV2Router01 {
    /**
     * @dev 移除ETH流动性并支持手续费转移
     * @param token 代币地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountTokenMin 最小获得的代币数量
     * @param amountETHMin 最小获得的ETH数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amountETH 获得的ETH数量
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    /**
     * @dev 通过permit移除ETH流动性并支持手续费转移
     * @param token 代币地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountTokenMin 最小获得的代币数量
     * @param amountETHMin 最小获得的ETH数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @param approveMax 是否授权最大值
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return amountETH 获得的ETH数量
     */
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    /**
     * @dev 精确代币输入交换并支持手续费转移
     * @param amountIn 输入代币数量
     * @param amountOutMin 最小输出代币数量
     * @param path 交换路径
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    /**
     * @dev 精确ETH输入交换并支持手续费转移
     * @param amountOutMin 最小输出代币数量
     * @param path 交换路径
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    /**
     * @dev 精确代币输入换ETH并支持手续费转移
     * @param amountIn 输入代币数量
     * @param amountOutMin 最小输出ETH数量
     * @param path 交换路径
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}