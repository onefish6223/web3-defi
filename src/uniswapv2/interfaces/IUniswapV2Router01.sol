// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title IUniswapV2Router01
 * @dev UniswapV2路由器接口V1
 * 提供了与UniswapV2交互的高级接口
 */
interface IUniswapV2Router01 {
    /**
     * @dev 获取工厂合约地址
     * @return 工厂合约地址
     */
    function factory() external view returns (address);

    /**
     * @dev 获取WETH合约地址
     * @return WETH合约地址
     */
    function WETH() external view returns (address);

    /**
     * @dev 添加流动性
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param amountADesired 期望添加的代币A数量
     * @param amountBDesired 期望添加的代币B数量
     * @param amountAMin 最小添加的代币A数量
     * @param amountBMin 最小添加的代币B数量
     * @param to 接收流动性代币的地址
     * @param deadline 交易截止时间
     * @return amountA 实际添加的代币A数量
     * @return amountB 实际添加的代币B数量
     * @return liquidity 获得的流动性代币数量
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /**
     * @dev 添加ETH流动性
     * @param token 代币地址
     * @param amountTokenDesired 期望添加的代币数量
     * @param amountTokenMin 最小添加的代币数量
     * @param amountETHMin 最小添加的ETH数量
     * @param to 接收流动性代币的地址
     * @param deadline 交易截止时间
     * @return amountToken 实际添加的代币数量
     * @return amountETH 实际添加的ETH数量
     * @return liquidity 获得的流动性代币数量
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    /**
     * @dev 移除流动性
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountAMin 最小获得的代币A数量
     * @param amountBMin 最小获得的代币B数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amountA 获得的代币A数量
     * @return amountB 获得的代币B数量
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @dev 移除ETH流动性
     * @param token 代币地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountTokenMin 最小获得的代币数量
     * @param amountETHMin 最小获得的ETH数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amountToken 获得的代币数量
     * @return amountETH 获得的ETH数量
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /**
     * @dev 通过permit移除流动性
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountAMin 最小获得的代币A数量
     * @param amountBMin 最小获得的代币B数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @param approveMax 是否授权最大值
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return amountA 获得的代币A数量
     * @return amountB 获得的代币B数量
     */
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @dev 通过permit移除ETH流动性
     * @param token 代币地址
     * @param liquidity 要移除的流动性代币数量
     * @param amountTokenMin 最小获得的代币数量
     * @param amountETHMin 最小获得的ETH数量
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @param approveMax 是否授权最大值
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return amountToken 获得的代币数量
     * @return amountETH 获得的ETH数量
     */
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    /**
     * @dev 精确输入交换
     * @param amountIn 输入代币数量
     * @param amountOutMin 最小输出代币数量
     * @param path 交换路径
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步的交换数量
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev 精确输出交换
     * @param amountOut 输出代币数量
     * @param amountInMax 最大输入代币数量
     * @param path 交换路径
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步的交换数量
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev 精确ETH输入交换
     * @param amountOutMin 最小输出代币数量
     * @param path 交换路径
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步的交换数量
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    /**
     * @dev 代币换精确ETH
     * @param amountOut 输出ETH数量
     * @param amountInMax 最大输入代币数量
     * @param path 交换路径
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步的交换数量
     */
    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts);

    /**
     * @dev 精确代币输入换ETH
     * @param amountIn 输入代币数量
     * @param amountOutMin 最小输出ETH数量
     * @param path 交换路径
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步的交换数量
     */
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts);

    /**
     * @dev ETH换精确代币
     * @param amountOut 输出代币数量
     * @param path 交换路径
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步的交换数量
     */
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    /**
     * @dev 计算给定输入数量的输出数量
     * @param amountIn 输入数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountOut 输出数量
     */
    function quote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut);

    /**
     * @dev 计算给定输入数量的输出数量（考虑手续费）
     * @param amountIn 输入数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountOut 输出数量
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut);

    /**
     * @dev 计算给定输出数量的输入数量（考虑手续费）
     * @param amountOut 输出数量
     * @param reserveIn 输入代币储备量
     * @param reserveOut 输出代币储备量
     * @return amountIn 输入数量
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountIn);

    /**
     * @dev 计算给定输入数量的输出数量数组
     * @param amountIn 输入数量
     * @param path 交换路径
     * @return amounts 输出数量数组
     */
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    /**
     * @dev 计算给定输出数量的输入数量数组
     * @param amountOut 输出数量
     * @param path 交换路径
     * @return amounts 输入数量数组
     */
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}