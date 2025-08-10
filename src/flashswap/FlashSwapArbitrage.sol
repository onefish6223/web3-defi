// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../uniswapv2/interfaces/IUniswapV2Callee.sol";
import "../uniswapv2/interfaces/IUniswapV2Factory.sol";
import "../uniswapv2/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../uniswapv2/libraries/UniswapV2Library.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FlashSwapArbitrage
 * @dev 闪电兑换套利合约，在两个Uniswap V2池子之间进行套利
 */
 // wake-disable
contract FlashSwapArbitrage is IUniswapV2Callee, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    // 两个Uniswap V2工厂合约地址
    address public immutable factoryA;
    address public immutable factoryB;
    
    // 事件
    event ArbitrageExecuted(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountBorrowed,
        uint256 profit
    );
    
    event ProfitWithdrawn(address indexed token, uint256 amount);
    
    constructor(
        address _factoryA,
        address _factoryB,
        address _owner
    ) Ownable(_owner) {
        factoryA = _factoryA;
        factoryB = _factoryB;
    }
    
    /**
     * @dev 执行套利交易
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param amountA 借入的代币A数量
     * @param isAtoB 是否从A池借入tokenA，在B池兑换为tokenB
     */
    function executeArbitrage(
        address tokenA,
        address tokenB,
        uint256 amountA,
        bool isAtoB
    ) external onlyOwner nonReentrant {
        require(tokenA != tokenB, "FlashSwap: IDENTICAL_TOKENS");
        require(amountA > 0, "FlashSwap: INVALID_AMOUNT");
        
        // 获取池子A的地址
        address pairA = IUniswapV2Factory(factoryA).getPair(tokenA, tokenB);
        require(pairA != address(0), "FlashSwap: PAIR_A_NOT_EXISTS");
        
        // 获取池子B的地址
        address pairB = IUniswapV2Factory(factoryB).getPair(tokenA, tokenB);
        require(pairB != address(0), "FlashSwap: PAIR_B_NOT_EXISTS");
        
        // 编码套利参数
        bytes memory data = abi.encode(
            tokenA,
            tokenB,
            amountA,
            isAtoB,
            pairB,
            msg.sender
        );
        
        // 确定借入的代币顺序
        address token0 = IUniswapV2Pair(pairA).token0();
        address token1 = IUniswapV2Pair(pairA).token1();
        
        uint256 amount0Out = tokenA == token0 ? amountA : 0;
        uint256 amount1Out = tokenA == token1 ? amountA : 0;
        
        // 从池子A发起闪电兑换
        IUniswapV2Pair(pairA).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
    }
    
    /**
     * @dev Uniswap V2回调函数，执行套利逻辑
     */
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // 解码参数
        (
            address tokenA,
            address tokenB,
            uint256 amountBorrowed,
            bool isAtoB,
            address pairB,
            address caller
        ) = abi.decode(data, (address, address, uint256, bool, address, address));
        
        // 验证调用者是合法的池子
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pairA = IUniswapV2Factory(factoryA).getPair(token0, token1);
        require(msg.sender == pairA, "FlashSwap: INVALID_CALLER");
        require(sender == address(this), "FlashSwap: INVALID_SENDER");
        
        // 确定实际借入的数量
        uint256 actualBorrowed = amount0 > 0 ? amount0 : amount1;
        require(actualBorrowed == amountBorrowed, "FlashSwap: AMOUNT_MISMATCH");
        
        // 执行套利逻辑
        uint256 profit = _performArbitrage(
            tokenA,
            tokenB,
            actualBorrowed,
            isAtoB,
            pairA,
            pairB
        );
        
        emit ArbitrageExecuted(tokenA, tokenB, actualBorrowed, profit);
    }
    
    /**
     * @dev 执行套利的核心逻辑
     */
    function _performArbitrage(
        address tokenA,
        address tokenB,
        uint256 amountBorrowed,
        bool isAtoB,
        address pairA,
        address pairB
    ) internal returns (uint256 profit) {
        IERC20 tokenAContract = IERC20(tokenA);
        IERC20 tokenBContract = IERC20(tokenB);
        
        // 在池子B中用借来的tokenA兑换tokenB
        uint256 amountBOut = _swapOnPair(
            pairB,
            tokenA,
            tokenB,
            amountBorrowed
        );
        // 在池子A中用部分tokenB换回足够的tokenA来还债
        uint256 amountBNeeded = _calculateAmountIn(pairA, tokenB, tokenA, amountBorrowed);
        
        // 检查是否有利润
        require(amountBOut > amountBNeeded, "FlashSwap: NO_PROFIT");
        
        // 直接归还 TokenB
        IERC20(tokenB).safeTransfer(pairA, amountBNeeded);
        
        // 计算利润（剩余的tokenB）
        profit = amountBOut - amountBNeeded;
    }
    
    /**
     * @dev 在指定池子中执行兑换
     */
    function _swapOnPair(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransfer(pair, amountIn);
        
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        
        if (tokenIn == token0) {
            amountOut = UniswapV2Library.getAmountOut(amountIn, reserve0, reserve1);
            IUniswapV2Pair(pair).swap(0, amountOut, address(this), new bytes(0));
        } else {
            amountOut = UniswapV2Library.getAmountOut(amountIn, reserve1, reserve0);
            IUniswapV2Pair(pair).swap(amountOut, 0, address(this), new bytes(0));
        }
    }
    
    /**
     * @dev 计算输入数量
     */
    function _calculateAmountIn(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) internal view returns (uint256) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        
        if (tokenIn == token0) {
            return UniswapV2Library.getAmountIn(amountOut, reserve0, reserve1);
        } else {
            return UniswapV2Library.getAmountIn(amountOut, reserve1, reserve0);
        }
    }
    
    /**
     * @dev 精确输出兑换
     */
    function _swapOnPairExactOut(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax
    ) internal {
        IERC20(tokenIn).safeTransfer(pair, amountInMax);
        
        address token0 = IUniswapV2Pair(pair).token0();
        
        if (tokenOut == token0) {
            IUniswapV2Pair(pair).swap(amountOut, 0, address(this), new bytes(0));
        } else {
            IUniswapV2Pair(pair).swap(0, amountOut, address(this), new bytes(0));
        }
    }
    
    /**
     * @dev 提取利润（仅所有者）
     */
    function withdrawProfit(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "FlashSwap: INVALID_AMOUNT");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance >= amount, "FlashSwap: INSUFFICIENT_BALANCE");
        
        tokenContract.safeTransfer(msg.sender, amount);
        emit ProfitWithdrawn(token, amount);
    }
    
    /**
     * @dev 查看代币余额
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /**
     * @dev 紧急提取所有代币（仅所有者）
     */
    function emergencyWithdraw(address token) external onlyOwner {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance > 0) {
            tokenContract.safeTransfer(msg.sender, balance);
        }
    }
}