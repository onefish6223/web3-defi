// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IUniswapV2Pair
 * @dev UniswapV2交易对合约接口
 * 交易对合约实现了两种代币之间的自动做市商功能
 */
interface IUniswapV2Pair {
    /**
     * @dev ERC20标准事件：代币转账
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev ERC20标准事件：授权
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev 添加流动性事件
     * @param sender 发送者地址
     * @param amount0 添加的token0数量
     * @param amount1 添加的token1数量
     */
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    /**
     * @dev 移除流动性事件
     * @param sender 发送者地址
     * @param amount0 移除的token0数量
     * @param amount1 移除的token1数量
     * @param to 接收代币的地址
     */
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    /**
     * @dev 代币交换事件
     * @param sender 发送者地址
     * @param amount0In 输入的token0数量
     * @param amount1In 输入的token1数量
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param to 接收代币的地址
     */
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /**
     * @dev 储备量同步事件
     * @param reserve0 token0的储备量
     * @param reserve1 token1的储备量
     */
    event Sync(uint112 reserve0, uint112 reserve1);

    // ERC20标准函数
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    // EIP-2612 permit函数相关
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    // UniswapV2特有函数
    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}