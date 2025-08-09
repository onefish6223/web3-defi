// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title TransferHelper
 * @dev 转账助手库
 * 提供安全的代币转账功能，处理不同类型的ERC20实现
 */
library TransferHelper {
    /**
     * @dev 安全转账ERC20代币
     * @param token 代币合约地址
     * @param to 接收地址
     * @param value 转账数量
     */
    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        // wake-disable-next-line reentrancy
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    /**
     * @dev 安全从某地址转账ERC20代币
     * @param token 代币合约地址
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账数量
     */
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        // wake-disable-next-line reentrancy
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    /**
     * @dev 安全转账ETH
     * @param to 接收地址
     * @param value 转账数量
     */
    function safeTransferETH(address to, uint256 value) internal {
        // wake-disable-next-line reentrancy
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}