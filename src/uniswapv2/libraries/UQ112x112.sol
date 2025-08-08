// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title UQ112x112
 * @dev 定点数库，用于处理112.112格式的定点数
 * 这种格式使用224位来表示一个定点数，其中前112位是整数部分，后112位是小数部分
 * 主要用于价格累积计算，避免浮点数精度问题
 */
library UQ112x112 {
    /**
     * @dev 2^112的值，用于编码和解码定点数
     */
    uint224 constant Q112 = 2**112;

    /**
     * @dev 将uint112编码为UQ112x112格式
     * @param y 要编码的uint112值
     * @return z 编码后的UQ112x112值
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // 永远不会溢出
    }

    /**
     * @dev UQ112x112除以uint112，返回UQ112x112
     * @param x UQ112x112格式的被除数
     * @param y uint112格式的除数
     * @return z UQ112x112格式的商
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}