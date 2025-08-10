// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '../interfaces/IUniswapV2Pair.sol';
import './FixedPoint.sol';

/**
 * @title UniswapV2OracleLibrary
 * @dev Uniswap V2 预言机库
 * 
 * 这个库提供了与 Uniswap V2 价格预言机相关的实用函数。
 * Uniswap V2 通过累积价格机制实现了去中心化的价格预言机功能，
 * 可以提供时间加权平均价格（TWAP），抵抗价格操纵攻击。
 * 
 * 核心概念：
 * 1. 累积价格：每个区块都会累积当前的价格
 * 2. 时间加权：通过时间间隔计算平均价格
 * 3. 抗操纵：单个交易无法显著影响长期平均价格
 */
library UniswapV2OracleLibrary {
    using FixedPoint for *;

    /**
     * @dev 获取当前的累积价格
     * @param pair 交易对合约地址
     * @return price0Cumulative token0 的累积价格
     * @return price1Cumulative token1 的累积价格
     * @return blockTimestamp 当前区块时间戳
     * 
     * 这个函数会检查是否需要更新累积价格，如果当前区块的时间戳
     * 与交易对中记录的时间戳不同，则会计算并返回更新后的累积价格。
     * 
     * 累积价格计算公式：
     * price0Cumulative += (reserve1 / reserve0) * timeElapsed
     * price1Cumulative += (reserve0 / reserve1) * timeElapsed
     */
    function currentCumulativePrices(address pair)
        internal
        view
        returns (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        )
    {
        // 获取当前区块时间戳
        blockTimestamp = currentBlockTimestamp();
        
        // 获取交易对中存储的累积价格和时间戳
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        // 获取当前储备量和最后更新时间戳
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        
        // 如果当前时间戳与最后更新时间戳不同，需要计算新的累积价格
        if (blockTimestampLast != blockTimestamp) {
            // 计算时间间隔（溢出是预期的，用于处理时间戳回绕）
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            
            // 只有在有流动性的情况下才更新累积价格
            if (reserve0 != 0 && reserve1 != 0) {
                // 计算并累加价格
                // price0 = reserve1 / reserve0 (token1 计价的 token0 价格)
                // price1 = reserve0 / reserve1 (token0 计价的 token1 价格)
                price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
                price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
            }
        }
    }

    /**
     * @dev 获取当前区块时间戳
     * @return 当前区块时间戳（截断为 uint32）
     * 
     * 注意：这里将时间戳截断为 uint32，这意味着它会在 2106 年溢出。
     * 这是 Uniswap V2 的设计选择，用于节省存储空间。
     */
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }

    /**
     * @dev 计算两个时间点之间的时间加权平均价格
     * @param priceCumulativeStart 开始时间的累积价格
     * @param priceCumulativeEnd 结束时间的累积价格
     * @param timeElapsed 时间间隔
     * @return priceAverage 时间加权平均价格
     * 
     * TWAP 计算公式：
     * TWAP = (累积价格差值) / 时间间隔
     * 
     * 这个函数用于计算任意两个时间点之间的平均价格，
     * 是实现价格预言机的核心函数。
     */
    function computeAveragePrice(
        uint256 priceCumulativeStart,
        uint256 priceCumulativeEnd,
        uint32 timeElapsed
    ) internal pure returns (FixedPoint.uq112x112 memory priceAverage) {
        require(timeElapsed > 0, 'UniswapV2OracleLibrary: PERIOD_NOT_ELAPSED');
        
        // 计算累积价格差值
        uint256 priceCumulativeDelta = priceCumulativeEnd - priceCumulativeStart;
        
        // 计算平均价格：差值除以时间间隔
        priceAverage = FixedPoint.uq112x112(
            uint224(priceCumulativeDelta / timeElapsed)
        );
    }

    /**
     * @dev 根据价格和输入数量计算输出数量
     * @param priceAverage 时间加权平均价格
     * @param amountIn 输入数量
     * @return amountOut 输出数量
     * 
     * 这个函数使用预言机价格来计算代币兑换数量，
     * 而不是使用当前的储备量比例。这样可以避免
     * 基于瞬时价格的操纵攻击。
     */
    function consultPrice(
        FixedPoint.uq112x112 memory priceAverage,
        uint256 amountIn
    ) internal pure returns (uint256 amountOut) {
        return priceAverage.mul(amountIn).decode144();
    }

    /**
     * @dev 检查交易对是否有足够的流动性进行预言机操作
     * @param pair 交易对合约地址
     * @return 如果有足够流动性返回 true，否则返回 false
     * 
     * 这个函数用于验证交易对是否适合作为价格预言机使用。
     * 没有流动性的交易对无法提供可靠的价格信息。
     */
    function hasLiquidity(address pair) internal view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        return reserve0 > 0 && reserve1 > 0;
    }

    /**
     * @dev 获取交易对的当前价格（基于储备量）
     * @param pair 交易对合约地址
     * @return price0 token0 的当前价格（用 token1 计价）
     * @return price1 token1 的当前价格（用 token0 计价）
     * 
     * 注意：这个函数返回的是瞬时价格，容易被操纵。
     * 在生产环境中应该使用时间加权平均价格。
     */
    function getCurrentPrice(address pair)
        internal
        view
        returns (
            FixedPoint.uq112x112 memory price0,
            FixedPoint.uq112x112 memory price1
        )
    {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, 'UniswapV2OracleLibrary: NO_RESERVES');
        
        price0 = FixedPoint.fraction(reserve1, reserve0);
        price1 = FixedPoint.fraction(reserve0, reserve1);
    }

    /**
     * @dev 计算给定时间窗口的最小观察次数
     * @param windowSize 时间窗口大小（秒）
     * @param granularity 观察粒度
     * @return 最小观察次数
     * 
     * 这个函数用于滑动窗口预言机，帮助确定需要多少个
     * 历史观察点来覆盖指定的时间窗口。
     */
    function getMinObservations(uint32 windowSize, uint8 granularity)
        internal
        pure
        returns (uint256)
    {
        require(granularity > 0, 'UniswapV2OracleLibrary: INVALID_GRANULARITY');
        return (windowSize / granularity) + 1;
    }
}