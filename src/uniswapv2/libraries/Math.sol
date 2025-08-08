// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title Math
 * @dev 数学计算库
 * 提供一些基础的数学计算功能
 */
library Math {
    /**
     * @dev 返回两个数中的较小值
     * @param x 第一个数
     * @param y 第二个数
     * @return z 较小值
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    /**
     * @dev 计算平方根（使用巴比伦方法）
     * @param y 输入值
     * @return z 平方根
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }else{// 如果y为0，z保持为0
            z = 0;
        }
        
    }
}