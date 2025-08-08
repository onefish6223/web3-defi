// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';
import './libraries/TransferHelper.sol';
import './libraries/UniswapV2Library.sol';
import './libraries/SafeMath.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IWETH.sol';

/**
 * @title UniswapV2Router02
 * @dev UniswapV2路由器合约 - Uniswap V2协议的核心路由合约
 * 
 * 这个合约提供了与UniswapV2协议交互的高级接口，主要功能包括：
 * 1. 流动性管理：添加和移除流动性
 * 2. 代币交换：支持各种类型的代币交换
 * 3. ETH处理：专门处理ETH与ERC20代币的交换
 * 4. 手续费代币支持：支持在转账时收取手续费的代币
 * 5. Permit功能：支持EIP-2612签名授权
 * 
 * 设计特点：
 * - 用户友好：简化了与Pair合约的直接交互
 * - 安全性：内置滑点保护和截止时间检查
 * - 灵活性：支持多种交换路径和代币类型
 * - Gas优化：通过批量操作减少交易成本
 */
contract UniswapV2Router02 is IUniswapV2Router02 {
    using SafeMath for uint256;

    /// @dev 工厂合约地址 - 用于创建和查找交易对
    address private immutable _factory;
    /// @dev WETH合约地址 - 包装以太坊合约，用于ETH与ERC20代币的交换
    address private immutable _WETH;
    
    // 重入攻击保护
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    /**
     * @dev 获取工厂合约地址
     * @return 工厂合约地址
     */
    function factory() external view override returns (address) {
        return _factory;
    }

    /**
     * @dev 获取WETH合约地址
     * @return WETH合约地址
     */
    function WETH() external view override returns (address) {
        return _WETH;
    }

    /**
     * @dev 确保交易在截止时间前完成的修饰符
     * @param deadline 交易截止时间戳
     * 
     * 这个修饰符用于防止交易在网络拥堵时被长时间挂起，
     * 保护用户免受价格滑点和MEV攻击的影响。
     */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    /**
     * @dev 构造函数 - 初始化路由器合约
     * @param factory_ UniswapV2Factory合约地址
     * @param WETH_ WETH合约地址
     * 
     * 这两个地址在部署后不可更改，确保了合约的安全性和可预测性。
     */
    constructor(address factory_, address WETH_) {
        _factory = factory_;
        _WETH = WETH_;
        _status = _NOT_ENTERED;
    }
    
    /**
     * @dev 防止重入攻击的修饰符
     */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /**
     * @dev 接收ETH的回调函数
     * 
     * 只接受来自WETH合约的ETH，这确保了：
     * 1. 防止意外的ETH转入
     * 2. 只有在WETH提取时才接收ETH
     * 3. 维护合约的ETH余额安全
     */
    receive() external payable {
        assert(msg.sender == _WETH); // 只接受来自WETH合约的ETH
    }

    // **** 添加流动性相关函数 ****
    /**
     * @dev 内部函数：计算添加流动性的最优代币数量
     * @param tokenA 代币A的地址
     * @param tokenB 代币B的地址
     * @param amountADesired 用户期望添加的代币A数量
     * @param amountBDesired 用户期望添加的代币B数量
     * @param amountAMin 用户可接受的代币A最小数量（滑点保护）
     * @param amountBMin 用户可接受的代币B最小数量（滑点保护）
     * @return amountA 实际需要的代币A数量
     * @return amountB 实际需要的代币B数量
     * 
     * 算法逻辑：
     * 1. 如果交易对不存在，自动创建
     * 2. 如果是首次添加流动性，直接使用用户期望的数量
     * 3. 如果已有流动性，按现有比例计算最优数量
     * 4. 使用双策略优化：优先满足较大的期望数量
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // 如果交易对不存在则创建 - 简化用户操作流程
        if (IUniswapV2Factory(_factory).getPair(tokenA, tokenB) == address(0)) {
            // wake-disable-next-line
            IUniswapV2Factory(_factory).createPair(tokenA, tokenB);
        }
        // 获取当前储备量
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(_factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            // 首次添加流动性：用户可以自由设定初始价格比例
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // 后续添加流动性：必须按现有比例添加
            // 策略A：以tokenA为基准计算所需的tokenB数量
            uint256 amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                // 如果计算出的tokenB数量不超过用户期望，使用策略A
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // 策略B：以tokenB为基准计算所需的tokenA数量
                uint256 amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired); // 数学上必然成立
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
     * @dev 添加ERC20代币流动性
     * @param tokenA 代币A的地址
     * @param tokenB 代币B的地址
     * @param amountADesired 用户期望添加的代币A数量
     * @param amountBDesired 用户期望添加的代币B数量
     * @param amountAMin 用户可接受的代币A最小数量（滑点保护）
     * @param amountBMin 用户可接受的代币B最小数量（滑点保护）
     * @param to 接收LP代币的地址
     * @param deadline 交易截止时间
     * @return amountA 实际添加的代币A数量
     * @return amountB 实际添加的代币B数量
     * @return liquidity 获得的LP代币数量
     * 
     * 执行流程：
     * 1. 计算最优添加数量
     * 2. 将代币转入交易对合约
     * 3. 调用Pair合约的mint函数铸造LP代币
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
    ) external virtual override ensure(deadline) nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // 计算最优添加数量
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(_factory, tokenA, tokenB);
        // 将代币从用户转入交易对合约
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // 铸造LP代币给指定地址
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    /**
     * @dev 添加ETH与ERC20代币的流动性
     * @param token ERC20代币的地址
     * @param amountTokenDesired 用户期望添加的代币数量
     * @param amountTokenMin 用户可接受的代币最小数量（滑点保护）
     * @param amountETHMin 用户可接受的ETH最小数量（滑点保护）
     * @param to 接收LP代币的地址
     * @param deadline 交易截止时间
     * @return amountToken 实际添加的代币数量
     * @return amountETH 实际添加的ETH数量
     * @return liquidity 获得的LP代币数量
     * 
     * 特殊处理：
     * 1. 将ETH包装为WETH进行处理
     * 2. 自动退还多余的ETH给用户
     * 3. 使用msg.value作为ETH的期望数量
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) nonReentrant returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        // 计算最优添加数量（将ETH视为WETH处理）
        (amountToken, amountETH) = _addLiquidity(
            token,
            _WETH,
            amountTokenDesired,
            msg.value, // 用户发送的ETH数量作为期望数量
            amountTokenMin,
            amountETHMin
        );
        // 获取token-WETH交易对地址
        address pair = UniswapV2Library.pairFor(_factory, token, _WETH);
        // 将ERC20代币从用户转入交易对
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        // 将ETH包装为WETH并转入交易对
        IWETH(_WETH).deposit{value: amountETH}();
        // wake-disable-next-line
        require(IWETH(_WETH).transfer(pair, amountETH), 'UniswapV2Router: WETH_TRANSFER_FAILED');
        // 铸造LP代币给指定地址
        // wake-disable-next-line
        liquidity = IUniswapV2Pair(pair).mint(to);
        // 退还多余的ETH给用户（如果有的话）
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** 移除流动性相关函数 ****
    /**
     * @dev 移除ERC20代币流动性
     * @param tokenA 代币A的地址
     * @param tokenB 代币B的地址
     * @param liquidity 要销毁的LP代币数量
     * @param amountAMin 用户可接受的代币A最小数量（滑点保护）
     * @param amountBMin 用户可接受的代币B最小数量（滑点保护）
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @return amountA 获得的代币A数量
     * @return amountB 获得的代币B数量
     * 
     * 执行流程：
     * 1. 将LP代币转入交易对合约
     * 2. 调用Pair合约的burn函数销毁LP代币
     * 3. 按比例获得底层代币
     * 4. 验证获得的代币数量满足最小要求
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) nonReentrant returns (uint256 amountA, uint256 amountB) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(_factory, tokenA, tokenB);
        // 将LP代币从用户转入交易对合约（准备销毁）
        // wake-disable-next-line
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);
        // 销毁LP代币，获得底层代币
        // wake-disable-next-line
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
        // 根据代币排序确定返回值的对应关系
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        // 滑点保护：确保获得的代币数量满足最小要求
        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    /**
     * @dev 移除ETH与ERC20代币的流动性
     * @param token ERC20代币的地址
     * @param liquidity 要销毁的LP代币数量
     * @param amountTokenMin 用户可接受的代币最小数量（滑点保护）
     * @param amountETHMin 用户可接受的ETH最小数量（滑点保护）
     * @param to 接收代币和ETH的地址
     * @param deadline 交易截止时间
     * @return amountToken 获得的代币数量
     * @return amountETH 获得的ETH数量
     * 
     * 特殊处理：
     * 1. 先移除token-WETH流动性到Router合约
     * 2. 将WETH解包装为ETH
     * 3. 分别转账代币和ETH给用户
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) nonReentrant returns (uint256 amountToken, uint256 amountETH) {
        // 移除token-WETH流动性，代币先转到Router合约
        (amountToken, amountETH) = removeLiquidity(
            token,
            _WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this), // 代币先转到Router合约进行处理
            deadline
        );
        // 将ERC20代币转给用户
        TransferHelper.safeTransfer(token, to, amountToken);
        // 将WETH解包装为ETH
        IWETH(_WETH).withdraw(amountETH);
        // 将ETH转给用户
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * @dev 使用EIP-2612 Permit签名移除ERC20代币流动性
     * @param tokenA 代币A的地址
     * @param tokenB 代币B的地址
     * @param liquidity 要销毁的LP代币数量
     * @param amountAMin 用户可接受的代币A最小数量（滑点保护）
     * @param amountBMin 用户可接受的代币B最小数量（滑点保护）
     * @param to 接收代币的地址
     * @param deadline 交易截止时间
     * @param approveMax 是否授权最大数量（节省gas）
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return amountA 获得的代币A数量
     * @return amountB 获得的代币B数量
     * 
     * 优势：
     * 1. 无需预先调用approve，节省一笔交易
     * 2. 使用链下签名，提升用户体验
     * 3. 支持一键式流动性移除
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
    ) external virtual override nonReentrant returns (uint256 amountA, uint256 amountB) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(_factory, tokenA, tokenB);
        // 确定授权数量：最大值或实际需要的数量
        uint256 value = approveMax ? type(uint256).max : liquidity;
        // 使用permit签名进行授权（无需预先approve）
        // wake-disable-next-line
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        // 执行流动性移除
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /**
     * @dev 使用EIP-2612 Permit签名移除ETH与ERC20代币的流动性
     * @param token ERC20代币的地址
     * @param liquidity 要销毁的LP代币数量
     * @param amountTokenMin 用户可接受的代币最小数量（滑点保护）
     * @param amountETHMin 用户可接受的ETH最小数量（滑点保护）
     * @param to 接收代币和ETH的地址
     * @param deadline 交易截止时间
     * @param approveMax 是否授权最大数量（节省gas）
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return amountToken 获得的代币数量
     * @return amountETH 获得的ETH数量
     * 
     * 特点：
     * 1. 结合了Permit签名和ETH流动性移除
     * 2. 自动处理WETH的解包装
     * 3. 一笔交易完成授权和流动性移除
     */
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override nonReentrant returns (uint256 amountToken, uint256 amountETH) {
        // 获取token-WETH交易对地址
        address pair = UniswapV2Library.pairFor(_factory, token, _WETH);
        // 确定授权数量：最大值或实际需要的数量
        uint256 value = approveMax ? type(uint256).max : liquidity;
        // 使用permit签名进行授权（无需预先approve）
        // wake-disable-next-line
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        // 执行ETH流动性移除
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** 移除流动性（支持手续费转移代币）****
    /**
     * @dev 移除ETH流动性并支持手续费转移代币
     * @param token ERC20代币的地址（支持转账手续费的代币）
     * @param liquidity 要销毁的LP代币数量
     * @param amountTokenMin 用户可接受的代币最小数量（滑点保护）
     * @param amountETHMin 用户可接受的ETH最小数量（滑点保护）
     * @param to 接收代币和ETH的地址
     * @param deadline 交易截止时间
     * @return amountETH 获得的ETH数量
     * 
     * 特殊处理：
     * 1. 支持转账时收取手续费的代币（如某些通缩代币）
     * 2. 通过余额检查确定实际收到的代币数量
     * 3. 不返回代币数量，因为可能与预期不符
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) nonReentrant returns (uint256 amountETH) {
        // 移除token-WETH流动性到Router合约
        (, amountETH) = removeLiquidity(
            token,
            _WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this), // 先转到Router合约
            deadline
        );
        // 将实际收到的代币数量转给用户（处理手续费代币）
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        if (tokenBalance > 0) {
            TransferHelper.safeTransfer(token, to, tokenBalance);
        }
        // 将WETH解包装为ETH
        IWETH(_WETH).withdraw(amountETH);
        // 将ETH转给用户
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * @dev 使用EIP-2612 Permit签名移除ETH流动性并支持手续费转移代币
     * @param token ERC20代币的地址（支持转账手续费的代币）
     * @param liquidity 要销毁的LP代币数量
     * @param amountTokenMin 用户可接受的代币最小数量（滑点保护）
     * @param amountETHMin 用户可接受的ETH最小数量（滑点保护）
     * @param to 接收代币和ETH的地址
     * @param deadline 交易截止时间
     * @param approveMax 是否授权最大数量（节省gas）
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     * @return amountETH 获得的ETH数量
     * 
     * 综合功能：
     * 1. Permit签名授权 + ETH流动性移除 + 手续费代币支持
     * 2. 最高级别的用户体验和兼容性
     * 3. 一笔交易完成所有操作
     */
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override nonReentrant returns (uint256 amountETH) {
        // 获取token-WETH交易对地址
        address pair = UniswapV2Library.pairFor(_factory, token, _WETH);
        // 确定授权数量：最大值或实际需要的数量
        uint256 value = approveMax ? type(uint256).max : liquidity;
        // 使用permit签名进行授权（无需预先approve）
        // wake-disable-next-line
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        // 执行支持手续费代币的ETH流动性移除
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** 代币交换相关函数 ****
    /**
     * @dev 内部交换函数 - 执行多跳代币交换的核心逻辑
     * @param amounts 每一步交换的数量数组（已预先计算）
     * @param path 交换路径数组（代币地址序列）
     * @param _to 最终接收代币的地址
     * 
     * 执行流程：
     * 1. 遍历交换路径中的每一对代币
     * 2. 确定每个交易对的输出数量和方向
     * 3. 计算下一步的接收地址（链式交换）
     * 4. 调用Pair合约的swap函数执行交换
     * 
     * 优化特点：
     * - 支持任意长度的交换路径
     * - 自动处理中间代币的转移
     * - 最后一步直接转给最终用户
     */
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            // 获取当前交换对的输入和输出代币
            (address input, address output) = (path[i], path[i + 1]);
            // 获取代币排序后的token0（用于确定swap参数）
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            // 获取当前步骤的输出数量
            uint256 amountOut = amounts[i + 1];
            // 根据代币顺序确定swap函数的参数
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            // 确定接收地址：如果不是最后一步，转到下一个交易对；否则转给最终用户
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(_factory, output, path[i + 2]) : _to;
            // 执行交换
            // wake-disable-next-line
            IUniswapV2Pair(UniswapV2Library.pairFor(_factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    /**
     * @dev 根据精确的输入数量进行代币交换
     * @param amountIn 精确的输入代币数量
     * @param amountOutMin 用户可接受的最小输出数量（滑点保护）
     * @param path 交换路径数组（从输入代币到输出代币）
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交换的数量数组
     * 
     * 特点：
     * 1. 输入数量固定，输出数量可变
     * 2. 支持多跳交换（通过path数组）
     * 3. 滑点保护确保最小输出
     * 4. 最常用的交换模式
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) nonReentrant returns (uint256[] memory amounts) {
        // 计算整个交换路径的数量数组
        amounts = UniswapV2Library.getAmountsOut(_factory, amountIn, path);
        // 滑点保护：确保最终输出不少于最小要求
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // 将输入代币从用户转入第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        // 执行交换链
        _swap(amounts, path, to);
    }

    /**
     * @dev 根据精确的输出数量进行代币交换
     * @param amountOut 精确的输出代币数量
     * @param amountInMax 用户可接受的最大输入数量（滑点保护）
     * @param path 交换路径数组（从输入代币到输出代币）
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交换的数量数组
     * 
     * 特点：
     * 1. 输出数量固定，输入数量可变
     * 2. 适用于需要精确输出数量的场景
     * 3. 滑点保护确保输入不超过最大值
     * 4. 反向计算交换路径
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) nonReentrant returns (uint256[] memory amounts) {
        // 反向计算整个交换路径的数量数组
        amounts = UniswapV2Library.getAmountsIn(_factory, amountOut, path);
        // 滑点保护：确保所需输入不超过用户设定的最大值
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        // 将计算出的输入代币从用户转入第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        // 执行交换链
        _swap(amounts, path, to);
    }

    /**
     * @dev 使用精确的ETH数量交换代币
     * @param amountOutMin 用户可接受的最小输出代币数量（滑点保护）
     * @param path 交换路径数组（必须以WETH开始）
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交换的数量数组
     * 
     * 特点：
     * 1. 使用msg.value作为精确的ETH输入
     * 2. 自动将ETH包装为WETH进行交换
     * 3. 路径必须以WETH开始
     * 4. 简化了ETH交换的用户体验
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        // 验证路径：必须以WETH开始
        require(path[0] == _WETH, 'UniswapV2Router: INVALID_PATH');
        // 计算交换路径的数量数组（使用msg.value作为输入）
        amounts = UniswapV2Library.getAmountsOut(_factory, msg.value, path);
        // 滑点保护：确保最终输出不少于最小要求
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // 将ETH包装为WETH
        IWETH(_WETH).deposit{value: amounts[0]}();
        // 将WETH转入第一个交易对
        // wake-disable-next-line
        require(IWETH(_WETH).transfer(UniswapV2Library.pairFor(_factory, path[0], path[1]), amounts[0]), 'UniswapV2Router: WETH_TRANSFER_FAILED');
        // 执行交换链
        _swap(amounts, path, to);
    }

    /**
     * @dev 使用代币交换精确数量的ETH
     * @param amountOut 精确的ETH输出数量
     * @param amountInMax 用户可接受的最大代币输入数量（滑点保护）
     * @param path 交换路径数组（必须以WETH结束）
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交换的数量数组
     * 
     * 特点：
     * 1. 输出精确数量的ETH
     * 2. 自动将WETH解包装为ETH
     * 3. 路径必须以WETH结束
     * 4. 中间步骤通过Router合约中转
     */
    function swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        // 验证路径：必须以WETH结束
        require(path[path.length - 1] == _WETH, 'UniswapV2Router: INVALID_PATH');
        // 反向计算交换路径的数量数组
        amounts = UniswapV2Library.getAmountsIn(_factory, amountOut, path);
        // 滑点保护：确保所需输入不超过用户设定的最大值
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        // 将输入代币从用户转入第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        // 执行交换链，WETH先转到Router合约
        _swap(amounts, path, address(this));
        // 将WETH解包装为ETH
        IWETH(_WETH).withdraw(amounts[amounts.length - 1]);
        // 将ETH转给用户
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /**
     * @dev 使用精确的代币数量交换ETH
     * @param amountIn 精确的输入代币数量
     * @param amountOutMin 用户可接受的最小ETH输出数量（滑点保护）
     * @param path 交换路径数组（必须以WETH结束）
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交换的数量数组
     * 
     * 特点：
     * 1. 输入精确数量的代币
     * 2. 自动将WETH解包装为ETH
     * 3. 路径必须以WETH结束
     * 4. 最常用的代币换ETH模式
     */
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        // 验证路径：必须以WETH结束
        require(path[path.length - 1] == _WETH, 'UniswapV2Router: INVALID_PATH');
        // 计算交换路径的数量数组
        amounts = UniswapV2Library.getAmountsOut(_factory, amountIn, path);
        // 滑点保护：确保最终ETH输出不少于最小要求
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // 将输入代币从用户转入第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        // 执行交换链，WETH先转到Router合约
        _swap(amounts, path, address(this));
        // 将WETH解包装为ETH
        IWETH(_WETH).withdraw(amounts[amounts.length - 1]);
        // 将ETH转给用户
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /**
     * @dev 使用ETH交换精确数量的代币
     * @param amountOut 精确的输出代币数量
     * @param path 交换路径数组（必须以WETH开始）
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * @return amounts 每一步交换的数量数组
     * 
     * 特点：
     * 1. 输出精确数量的代币
     * 2. 自动退还多余的ETH
     * 3. 路径必须以WETH开始
     * 4. 用户发送的ETH作为最大输入限制
     */
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        // 验证路径：必须以WETH开始
        require(path[0] == _WETH, 'UniswapV2Router: INVALID_PATH');
        // 反向计算交换路径的数量数组
        amounts = UniswapV2Library.getAmountsIn(_factory, amountOut, path);
        // 滑点保护：确保所需ETH不超过用户发送的数量
        require(amounts[0] <= msg.value, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        // 将所需的ETH包装为WETH
        IWETH(_WETH).deposit{value: amounts[0]}();
        // 将WETH转入第一个交易对
        // wake-disable-next-line
        require(IWETH(_WETH).transfer(UniswapV2Library.pairFor(_factory, path[0], path[1]), amounts[0]), 'UniswapV2Router: WETH_TRANSFER_FAILED');
        // 执行交换链
        _swap(amounts, path, to);
        // 退还多余的ETH给用户（如果有的话）
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** 支持手续费转移代币的交换函数 ****
    /**
     * @dev 内部交换函数（支持手续费转移代币）
     * @param path 交换路径数组
     * @param _to 最终接收代币的地址
     * 
     * 与普通交换的区别：
     * 1. 不依赖预先计算的amounts数组
     * 2. 通过余额检查确定实际转入的代币数量
     * 3. 动态计算每一步的输出数量
     * 4. 支持转账时收取手续费的代币
     * 
     * 算法流程：
     * 1. 检查交易对的实际余额变化
     * 2. 计算扣除手续费后的实际输入数量
     * 3. 基于实际输入计算输出数量
     * 4. 执行交换并传递到下一个交易对
     */
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            // 获取当前交换对的输入和输出代币
            (address input, address output) = (path[i], path[i + 1]);
            // 获取代币排序后的token0（用于确定swap参数）
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            // 获取交易对合约实例
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(_factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            { // 使用代码块避免堆栈过深错误
            // 获取当前储备量
            (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
            // 根据代币顺序确定输入和输出储备量
            (uint256 reserveInput, uint256 reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            // 关键：通过余额差值计算实际输入数量（处理手续费代币）
            uint256 pairBalance = IERC20(input).balanceOf(address(pair));
            require(pairBalance >= reserveInput, 'UniswapV2Router: INSUFFICIENT_INPUT_AMOUNT');
            amountInput = pairBalance.sub(reserveInput);
            // 基于实际输入数量计算输出数量
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            // 根据代币顺序确定swap函数的参数
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            // 确定接收地址：如果不是最后一步，转到下一个交易对；否则转给最终用户
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(_factory, output, path[i + 2]) : _to;
            // 执行交换
            // wake-disable-next-line
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /**
     * @dev 精确代币输入交换，支持转账手续费代币
     * @param amountIn 精确的输入代币数量
     * @param amountOutMin 用户可接受的最小输出数量（滑点保护）
     * @param path 交换路径数组（从输入代币到输出代币）
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * 
     * 特殊处理：
     * 1. 通过余额检查确定实际收到的代币数量
     * 2. 不返回amounts数组，因为手续费会影响预期数量
     * 3. 支持各种收费机制的代币（通缩代币、反射代币等）
     * 4. 使用前后余额差值进行滑点保护
     * 
     * 适用场景：
     * - 转账时自动销毁部分代币的通缩代币
     * - 转账时收取固定或比例手续费的代币
     * - 转账时进行重新分配的反射代币
     * - 其他具有特殊转账逻辑的代币
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) nonReentrant {
        // 将输入代币从用户转入第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(_factory, path[0], path[1]), amountIn
        );
        // 记录交换前的余额
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        // 执行支持手续费代币的交换
        _swapSupportingFeeOnTransferTokens(path, to);
        // 滑点保护：通过余额差值检查实际收到的数量
        uint256 balanceAfter = IERC20(path[path.length - 1]).balanceOf(to);
        require(
            balanceAfter.sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    /**
     * @dev 精确ETH输入交换，支持转账手续费代币
     * @param amountOutMin 用户可接受的最小输出代币数量（滑点保护）
     * @param path 交换路径数组（必须以WETH开始）
     * @param to 接收输出代币的地址
     * @param deadline 交易截止时间
     * 
     * 特点：
     * 1. 使用msg.value作为精确的ETH输入
     * 2. 自动将ETH包装为WETH进行交换
     * 3. 支持输出代币为手续费转移代币
     * 4. 通过余额检查进行滑点保护
     * 
     * 执行流程：
     * 1. 验证路径必须以WETH开始
     * 2. 将ETH包装为WETH
     * 3. 将WETH转入第一个交易对
     * 4. 执行支持手续费的交换链
     * 5. 检查最终收到的代币数量
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
        nonReentrant
    {
        // 验证路径：必须以WETH开始
        require(path[0] == _WETH, 'UniswapV2Router: INVALID_PATH');
        // 获取用户发送的ETH数量
        uint256 amountIn = msg.value;
        // 将ETH包装为WETH
        IWETH(_WETH).deposit{value: amountIn}();
        // 将WETH转入第一个交易对
        // wake-disable-next-line
        require(IWETH(_WETH).transfer(UniswapV2Library.pairFor(_factory, path[0], path[1]), amountIn), 'UniswapV2Router: WETH_TRANSFER_FAILED');
        // 记录交换前的余额
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        // 执行支持手续费代币的交换
        _swapSupportingFeeOnTransferTokens(path, to);
        // 滑点保护：通过余额差值检查实际收到的数量
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    /**
     * @dev 精确代币输入换ETH，支持转账手续费代币
     * @param amountIn 精确的输入代币数量
     * @param amountOutMin 用户可接受的最小ETH输出数量（滑点保护）
     * @param path 交换路径数组（必须以WETH结束）
     * @param to 接收ETH的地址
     * @param deadline 交易截止时间
     * 
     * 特点：
     * 1. 支持输入代币为手续费转移代币
     * 2. 自动将WETH解包装为ETH
     * 3. 通过Router合约中转处理WETH
     * 4. 基于实际WETH余额进行滑点保护
     * 
     * 执行流程：
     * 1. 验证路径必须以WETH结束
     * 2. 将输入代币转入第一个交易对
     * 3. 执行支持手续费的交换链，WETH转到Router
     * 4. 检查Router合约的WETH余额
     * 5. 将WETH解包装为ETH并转给用户
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        nonReentrant
    {
        // 验证路径：必须以WETH结束
        require(path[path.length - 1] == _WETH, 'UniswapV2Router: INVALID_PATH');
        // 将输入代币从用户转入第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(_factory, path[0], path[1]), amountIn
        );
        // 执行支持手续费代币的交换，WETH先转到Router合约
        _swapSupportingFeeOnTransferTokens(path, address(this));
        // 获取Router合约实际收到的WETH数量
        uint256 amountOut = IERC20(_WETH).balanceOf(address(this));
        require(amountOut > 0, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // 滑点保护：确保实际收到的WETH不少于最小要求
        require(amountOut >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        // 将WETH解包装为ETH
        IWETH(_WETH).withdraw(amountOut);
        // 将ETH转给用户
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** 库函数封装 - 提供公共查询接口 ****
    /**
     * @dev 根据储备量计算等价代币数量（价格比例计算）
     * @param amountA 已知的代币A数量
     * @param reserveA 代币A的储备量
     * @param reserveB 代币B的储备量
     * @return amountB 等价的代币B数量
     * 
     * 计算公式：amountB = amountA * reserveB / reserveA
     * 用途：
     * 1. 添加流动性时计算最优比例
     * 2. 价格查询和显示
     * 3. 前端界面的实时计算
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure virtual override returns (uint256 amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    /**
     * @dev 根据输入数量计算输出数量（考虑0.3%手续费）
     * @param amountIn 输入代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * @return amountOut 输出代币数量
     * 
     * 计算公式：基于恒定乘积公式 x * y = k
     * 考虑0.3%交易手续费：amountInWithFee = amountIn * 997
     * amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee)
     * 
     * 用途：
     * 1. 交换前的价格预览
     * 2. 滑点计算
     * 3. 套利机会分析
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
     * @dev 根据输出数量计算所需输入数量（考虑0.3%手续费）
     * @param amountOut 期望的输出代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * @return amountIn 所需的输入代币数量
     * 
     * 计算公式：反向计算恒定乘积公式
     * amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
     * 
     * 用途：
     * 1. 精确输出交换的价格计算
     * 2. 反向价格查询
     * 3. 流动性需求分析
     */
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /**
     * @dev 计算多跳交换路径的输出数量数组（给定输入数量）
     * @param amountIn 初始输入代币数量
     * @param path 交换路径数组（代币地址序列）
     * @return amounts 每一步交换的数量数组
     * 
     * 功能说明：
     * 1. 计算整个交换路径中每一步的输入和输出数量
     * 2. amounts[0] = amountIn（初始输入）
     * 3. amounts[i] = 第i步交换的输出数量
     * 4. amounts[amounts.length-1] = 最终输出数量
     * 
     * 算法流程：
     * - 遍历路径中的每一对代币
     * - 获取对应交易对的储备量
     * - 基于前一步的输出计算当前步的输出
     * - 考虑每一步的0.3%交易手续费
     * 
     * 用途：
     * 1. 多跳交换的价格预览
     * 2. 最优路径分析
     * 3. 滑点和手续费计算
     * 4. 前端显示交换详情
     */
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(_factory, amountIn, path);
    }

    /**
     * @dev 计算多跳交换路径的输入数量数组（给定输出数量）
     * @param amountOut 期望的最终输出代币数量
     * @param path 交换路径数组（代币地址序列）
     * @return amounts 每一步交换的数量数组
     * 
     * 功能说明：
     * 1. 反向计算整个交换路径中每一步的输入和输出数量
     * 2. amounts[amounts.length-1] = amountOut（期望输出）
     * 3. amounts[i] = 第i步交换的输入数量
     * 4. amounts[0] = 所需的初始输入数量
     * 
     * 算法流程：
     * - 从路径末端开始反向遍历
     * - 获取对应交易对的储备量
     * - 基于后一步的输入计算当前步的输入
     * - 考虑每一步的0.3%交易手续费
     * 
     * 用途：
     * 1. 精确输出交换的成本计算
     * 2. 反向价格查询
     * 3. 资金需求规划
     * 4. 交换可行性验证
     */
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(_factory, amountOut, path);
    }
}