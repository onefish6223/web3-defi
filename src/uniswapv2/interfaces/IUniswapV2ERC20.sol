// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IUniswapV2ERC20
 * @dev UniswapV2 ERC20代币接口
 * 扩展了标准ERC20接口，增加了EIP-2612 permit功能
 */
interface IUniswapV2ERC20 {
    /**
     * @dev ERC20标准事件：代币转账
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账金额
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev ERC20标准事件：授权
     * @param owner 代币所有者地址
     * @param spender 被授权者地址
     * @param value 授权金额
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev 获取代币名称
     * @return 代币名称
     */
    function name() external pure returns (string memory);

    /**
     * @dev 获取代币符号
     * @return 代币符号
     */
    function symbol() external pure returns (string memory);

    /**
     * @dev 获取代币小数位数
     * @return 小数位数
     */
    function decimals() external pure returns (uint8);

    /**
     * @dev 获取代币总供应量
     * @return 总供应量
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev 获取指定地址的代币余额
     * @param owner 地址
     * @return 余额
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @dev 获取授权额度
     * @param owner 代币所有者地址
     * @param spender 被授权者地址
     * @return 授权额度
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev 授权指定地址可以花费的代币数量
     * @param spender 被授权者地址
     * @param value 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev 转账代币
     * @param to 接收方地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev 从指定地址转账代币（需要授权）
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev EIP-712域分隔符
     * @return 域分隔符
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @dev EIP-2612 permit类型哈希
     * @return permit类型哈希
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /**
     * @dev 获取地址的nonce值（用于permit）
     * @param owner 地址
     * @return nonce值
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev EIP-2612 permit函数，允许通过签名进行授权
     * @param owner 代币所有者地址
     * @param spender 被授权者地址
     * @param value 授权金额
     * @param deadline 签名有效期
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}