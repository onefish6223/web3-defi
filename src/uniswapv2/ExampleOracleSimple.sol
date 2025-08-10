// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入 Uniswap V2 核心合约接口
import './interfaces/IUniswapV2Pair.sol';
// 导入固定点数学库，用于高精度价格计算
import './libraries/FixedPoint.sol';
// 导入 Uniswap V2 预言机库
import './libraries/UniswapV2OracleLibrary.sol';
// 导入 Uniswap V2 工具库
import './libraries/UniswapV2Library.sol';

/**
 * @title ExampleOracleSimple
 * @dev 简单的固定窗口预言机合约
 * 
 * 这是一个固定窗口预言机，每个周期重新计算整个周期的平均价格。
 * 注意：价格平均值只保证覆盖至少1个周期，但可能覆盖更长的周期。
 * 
 * 工作原理：
 * 1. 每24小时为一个周期
 * 2. 记录价格累积值和时间戳
 * 3. 通过累积价格差值计算时间加权平均价格(TWAP)
 * 4. 提供代币价格查询功能
 */
contract ExampleOracleSimple {
    // 使用 FixedPoint 库进行所有相关计算
    using FixedPoint for *;
    
    // 预言机更新周期：24小时
    uint public constant PERIOD = 24 hours;

    // 不可变的交易对合约地址
    IUniswapV2Pair immutable pair;
    // 交易对中的第一个代币地址（按字典序排序）
    address public immutable token0;
    // 交易对中的第二个代币地址（按字典序排序）
    address public immutable token1;

    // 上次记录的 token0 价格累积值
    uint public price0CumulativeLast;
    // 上次记录的 token1 价格累积值
    uint public price1CumulativeLast;
    // 上次更新的区块时间戳
    uint32 public blockTimestampLast;
    
    // token0 的时间加权平均价格（TWAP）
    FixedPoint.uq112x112 public price0Average;
    // token1 的时间加权平均价格（TWAP）
    FixedPoint.uq112x112 public price1Average;

    /**
     * @dev 构造函数
     * @param factory Uniswap V2 工厂合约地址
     * @param tokenA 交易对中的一个代币地址
     * @param tokenB 交易对中的另一个代币地址
     * 
     * 初始化预言机，设置交易对和代币地址，并进行首次价格记录
     */
    constructor(address factory, address tokenA, address tokenB) {
        // 通过工厂合约获取交易对地址
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        pair = _pair;
        // 获取交易对中按字典序排序的代币地址
        token0 = _pair.token0();
        token1 = _pair.token1();
        
        // 获取当前的价格累积值和时间戳
        price0CumulativeLast = _pair.price0CumulativeLast();
        price1CumulativeLast = _pair.price1CumulativeLast();
        
        // 获取当前区块时间戳
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        
        // 确保交易对有流动性
        require(reserve0 != 0 && reserve1 != 0, 'ExampleOracleSimple: NO_RESERVES');
    }

    /**
     * @dev 更新预言机价格数据
     * 
     * 这个函数需要定期调用以更新价格数据。
     * 只有当距离上次更新超过一个周期时，才会更新平均价格。
     */
    function update() external {
        // 获取当前的价格累积值和时间戳
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = 
            UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        
        // 计算时间间隔（溢出是预期的，用于处理时间戳回绕）
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        // 确保至少经过了一个周期
        if (timeElapsed >= PERIOD) {
            // 计算 token0 的时间加权平均价格
            // 价格 = (当前累积价格 - 上次累积价格) / 时间间隔
            price0Average = FixedPoint.uq112x112(
                uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
            );
            
            // 计算 token1 的时间加权平均价格
            price1Average = FixedPoint.uq112x112(
                uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
            );

            // 更新存储的累积价格和时间戳
            price0CumulativeLast = price0Cumulative;
            price1CumulativeLast = price1Cumulative;
            blockTimestampLast = blockTimestamp;
        }
    }

    /**
     * @dev 查询代币价格
     * @param token 要查询价格的代币地址
     * @param amountIn 输入代币数量
     * @return amountOut 根据平均价格计算出的输出代币数量
     * 
     * 使用时间加权平均价格计算代币兑换数量
     */
    function consult(address token, uint amountIn) external view returns (uint amountOut) {
        if (token == token0) {
            // 如果查询的是 token0，使用 price0Average 计算
            // price0Average 表示用 token1 计价的 token0 价格
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            // 如果查询的是 token1，使用 price1Average 计算
            require(token == token1, 'ExampleOracleSimple: INVALID_TOKEN');
            // price1Average 表示用 token0 计价的 token1 价格
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    /**
     * @dev 获取上次更新后经过的时间
     * @return 距离上次更新的秒数
     */
    function getTimeElapsed() external view returns (uint32) {
        return uint32(block.timestamp) - blockTimestampLast;
    }

    /**
     * @dev 检查是否可以更新价格
     * @return 如果距离上次更新超过一个周期，返回 true
     */
    function canUpdate() external view returns (bool) {
        return (uint32(block.timestamp) - blockTimestampLast) >= PERIOD;
    }

    /**
     * @dev 获取交易对地址
     * @return 交易对合约地址
     */
    function getPair() external view returns (address) {
        return address(pair);
    }
}