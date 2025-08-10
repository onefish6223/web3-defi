// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title FixedPoint
 * @dev 定点数数学库
 * 
 * 这个库实现了 UQ112x112 格式的定点数运算，用于高精度的价格计算。
 * UQ112x112 表示：
 * - U: 无符号 (Unsigned)
 * - Q: 定点数 (Q-format)
 * - 112x112: 112位整数部分 + 112位小数部分 = 224位总长度
 * 
 * 这种格式特别适合 Uniswap 的价格计算，因为它提供了足够的精度
 * 来处理代币价格的微小变化，同时避免了浮点数运算的复杂性。
 */
library FixedPoint {
    // 定点数的小数部分位数
    uint8 public constant RESOLUTION = 112;
    // 2^112，用于定点数转换
    uint256 public constant Q112 = 0x10000000000000000000000000000; // 2**112
    
    /**
     * @dev UQ112x112 定点数结构体
     * 使用 224 位来存储一个定点数：
     * - 高 112 位：整数部分
     * - 低 112 位：小数部分
     */
    struct uq112x112 {
        uint224 _x;
    }

    /**
     * @dev UQ144x112 定点数结构体
     * 使用 256 位来存储更大范围的定点数：
     * - 高 144 位：整数部分
     * - 低 112 位：小数部分
     */
    struct uq144x112 {
        uint256 _x;
    }

    /**
     * @dev 将 uint112 编码为 UQ112x112 定点数
     * @param x 要编码的整数
     * @return 编码后的定点数
     * 
     * 编码过程：将整数左移 112 位，使其成为定点数的整数部分
     */
    function encode(uint112 x) internal pure returns (uq112x112 memory) {
        return uq112x112(uint224(x) << RESOLUTION);
    }

    /**
     * @dev 将 uint144 编码为 UQ144x112 定点数
     * @param x 要编码的整数
     * @return 编码后的定点数
     */
    function encode144(uint144 x) internal pure returns (uq144x112 memory) {
        return uq144x112(uint256(x) << RESOLUTION);
    }

    /**
     * @dev 将两个 uint112 相除并返回 UQ112x112 定点数
     * @param x 被除数
     * @param y 除数
     * @return 相除结果的定点数表示
     * 
     * 计算公式：(x << 112) / y
     * 这样可以保持除法结果的精度
     */
    function fraction(uint112 x, uint112 y) internal pure returns (uq112x112 memory) {
        require(y > 0, 'FixedPoint: DIV_BY_ZERO');
        return uq112x112((uint224(x) << RESOLUTION) / y);
    }

    /**
     * @dev 将 UQ112x112 定点数解码为 uint112 整数
     * @param self 要解码的定点数
     * @return 解码后的整数（只保留整数部分）
     * 
     * 解码过程：将定点数右移 112 位，丢弃小数部分
     */
    function decode(uq112x112 memory self) internal pure returns (uint112) {
        return uint112(self._x >> RESOLUTION);
    }

    /**
     * @dev 将 UQ144x112 定点数解码为 uint144 整数
     * @param self 要解码的定点数
     * @return 解码后的整数（只保留整数部分）
     */
    function decode144(uq144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> RESOLUTION);
    }

    /**
     * @dev UQ112x112 定点数乘法
     * @param self 第一个定点数
     * @param y 要乘的整数
     * @return 乘法结果（UQ144x112 格式）
     * 
     * 注意：结果使用更大的 UQ144x112 格式以防止溢出
     */
    function mul(uq112x112 memory self, uint256 y) internal pure returns (uq144x112 memory) {
        uint256 z = 0;
        require(y == 0 || (z = self._x * y) / y == self._x, 'FixedPoint: MUL_OVERFLOW');
        return uq144x112(z);
    }

    /**
     * @dev UQ112x112 定点数乘以 UQ112x112 定点数
     * @param self 第一个定点数
     * @param other 第二个定点数
     * @return 乘法结果（UQ112x112 格式）
     * 
     * 计算过程：
     * 1. 两个定点数相乘得到 224+224=448 位结果
     * 2. 右移 112 位以保持定点数格式
     * 3. 截断到 224 位
     */
    function muluq(uq112x112 memory self, uq112x112 memory other) internal pure returns (uq112x112 memory) {
        if (self._x == 0 || other._x == 0) {
            return uq112x112(0);
        }
        uint112 upper_self = uint112(self._x >> RESOLUTION); // 整数部分
        uint112 lower_self = uint112(self._x & 0xffffffffffffffffffffffffffff); // 小数部分
        uint112 upper_other = uint112(other._x >> RESOLUTION); // 整数部分
        uint112 lower_other = uint112(other._x & 0xffffffffffffffffffffffffffff); // 小数部分

        // 部分乘积计算
        uint224 upper = uint224(upper_self) * upper_other;
        uint224 lower = uint224(lower_self) * lower_other;
        uint224 uppers_lowero = uint224(upper_self) * lower_other;
        uint224 uppero_lowers = uint224(upper_other) * lower_self;

        // 检查溢出
        require(upper <= type(uint112).max, 'FixedPoint: MULUQ_OVERFLOW_UPPER');

        // 组合结果
        uint256 sum = uint256(upper << RESOLUTION) + uppers_lowero + uppero_lowers + (lower >> RESOLUTION);
        require(sum <= type(uint224).max, 'FixedPoint: MULUQ_OVERFLOW_SUM');

        return uq112x112(uint224(sum));
    }

    /**
     * @dev UQ112x112 定点数除法
     * @param self 被除数
     * @param other 除数
     * @return 除法结果（UQ112x112 格式）
     */
    function divuq(uq112x112 memory self, uq112x112 memory other) internal pure returns (uq112x112 memory) {
        require(other._x > 0, 'FixedPoint: DIV_BY_ZERO');
        return uq112x112(uint224((uint256(self._x) << RESOLUTION) / other._x));
    }

    /**
     * @dev 计算定点数的倒数
     * @param self 要计算倒数的定点数
     * @return 倒数结果（UQ112x112 格式）
     * 
     * 计算公式：1 / self = (2^112 * 2^112) / self._x
     */
    function reciprocal(uq112x112 memory self) internal pure returns (uq112x112 memory) {
        require(self._x != 0, 'FixedPoint: RECIPROCAL_ZERO');
        return uq112x112(uint224(Q112 * Q112) / self._x);
    }

    /**
     * @dev 计算平方根（使用巴比伦方法）
     * @param self 要计算平方根的定点数
     * @return 平方根结果（UQ112x112 格式）
     */
    function sqrt(uq112x112 memory self) internal pure returns (uq112x112 memory) {
        if (self._x <= 1) {
            return uq112x112(uint224(self._x));
        }
        
        uint224 z = self._x;
        uint224 x = self._x / 2 + 1;
        
        // 巴比伦方法迭代
        while (x < z) {
            z = x;
            x = (self._x / x + x) / 2;
        }
        
        return uq112x112(z);
    }
}