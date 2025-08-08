// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '../interfaces/IUniswapV2Pair.sol';
import './SafeMath.sol';

/**
 * @title UniswapV2Library
 * @dev UniswapV2库函数
 * 提供了路由器所需的各种计算函数
 */
library UniswapV2Library {
    using SafeMath for uint256;

    /**
     * @dev 按字典序排序代币地址
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return token0 较小的代币地址
     * @return token1 较大的代币地址
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @dev 计算交易对地址
     * @param factory 工厂合约地址
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return pair 交易对地址
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'a9dbbc1267b4844906ad57671951356584dc44bbfb709f6e9da22f53005f8195' // init code hash
            )))));
    }

    /**
     * @dev 获取储备量
     * @param factory 工厂合约地址
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return reserveA 代币A储备量
     * @return reserveB 代币B储备量
     */
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev 计算报价
     * @param amountA 代币A数量
     * @param reserveA 代币A储备量
     * @param reserveB 代币B储备量
     * @return amountB 代币B数量
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * @dev 计算给定输入数量的输出数量
     * @param amountIn 输入数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountOut 输出数量
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    /**
     * @dev 计算给定输出数量的输入数量
     * @param amountOut 输出数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountIn 输入数量
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    /**
     * @dev 计算给定输入数量的输出数量数组
     * @param factory 工厂合约地址
     * @param amountIn 输入数量
     * @param path 交换路径
     * @return amounts 输出数量数组
     */
    function getAmountsOut(address factory, uint256 amountIn, address[] memory path) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev 计算给定输出数量的输入数量数组
     * @param factory 工厂合约地址
     * @param amountOut 输出数量
     * @param path 交换路径
     * @return amounts 输入数量数组
     */
    function getAmountsIn(address factory, uint256 amountOut, address[] memory path) internal view returns (uint256[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}