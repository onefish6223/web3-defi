// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title SafeMath
 * @dev 安全数学运算库
 * 注意：Solidity 0.8.x版本已经内置了溢出检查，但为了保持与原版UniswapV2的兼容性
 * 仍然提供此库。在实际使用中，可以直接使用内置的算术运算符。
 */
library SafeMath {
    /**
     * @dev 安全加法
     * @param a 第一个数
     * @param b 第二个数
     * @return 两数之和
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev 安全减法
     * @param a 被减数
     * @param b 减数
     * @return 两数之差
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev 安全减法（带自定义错误信息）
     * @param a 被减数
     * @param b 减数
     * @param errorMessage 错误信息
     * @return 两数之差
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    /**
     * @dev 安全乘法
     * @param a 第一个数
     * @param b 第二个数
     * @return 两数之积
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // 优化：如果a为0，直接返回0
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev 安全除法
     * @param a 被除数
     * @param b 除数
     * @return 两数之商
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev 安全除法（带自定义错误信息）
     * @param a 被除数
     * @param b 除数
     * @param errorMessage 错误信息
     * @return 两数之商
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

    /**
     * @dev 安全取模
     * @param a 被除数
     * @param b 除数
     * @return 取模结果
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev 安全取模（带自定义错误信息）
     * @param a 被除数
     * @param b 除数
     * @param errorMessage 错误信息
     * @return 取模结果
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}