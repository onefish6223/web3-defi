// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title ILendingPool
 * @dev 简化的借贷市场接口，参考 Aave/Compound
 */
interface ILendingPool {
    /**
     * @dev 存入 ETH 到借贷市场
     */
    function depositETH() external payable;
    
    /**
     * @dev 提取 ETH 从借贷市场
     * @param amount 提取数量
     */
    function withdrawETH(uint256 amount) external;
    
    /**
     * @dev 获取存款余额（包含利息）
     * @param user 用户地址
     * @return 存款余额
     */
    function getBalance(address user) external view returns (uint256);
}