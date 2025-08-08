// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "./UniswapV2ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/SafeMath.sol";

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

/**
 * @title UniswapV2Pair
 * @dev UniswapV2交易对合约
 * 实现了两种代币之间的自动做市商功能，包括添加/移除流动性、代币交换等
 */
contract UniswapV2Pair is UniswapV2ERC20 {
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    // 最小流动性，防止除零错误
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    
    // 选择器，用于低级调用
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    // 工厂合约地址
    address public factory;
    // 交易对中的两种代币地址
    address public token0;
    address public token1;

    // 储备量和最后更新时间（打包存储以节省gas）
    uint112 private reserve0;           // 使用单个存储槽
    uint112 private reserve1;           // 使用单个存储槽
    uint32  private blockTimestampLast; // 使用单个存储槽

    // 价格累积值，用于价格预言机
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    
    /**
     * @dev 储备量乘积，用于协议手续费计算
        // k 值的含义
        //   - k = reserve0 × reserve1 是恒定乘积公式中的常数
        //   - 在理想情况下，k 值只有在添加/移除流动性时才会改变
        //   - 但由于交易手续费的存在，每次交换后 k 值都会略微增加
        //   - k 值的增长反映了累积的交易手续费 
        // 协议手续费机制
        // 1. 交易手续费 : 每笔交换收取 0.3% 手续费，全部给流动性提供者
        // 2. 协议手续费 : 从交易手续费中额外收取 1/6，给协议方
        // 3. 实际分配 :
        //    - 流动性提供者获得: 0.25% (5/6 × 0.3%)
        //    - 协议方获得: 0.05% (1/6 × 0.3%)
    */
    uint256 public kLast; // reserve0 * reserve1, 在最近一次流动性事件后
    // 重入锁
    uint256 private unlocked = 1;

    // 事件声明
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    
    /**
     * @dev 重入保护修饰符
     */
    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /**
     * @dev 获取储备量
     * @return _reserve0 token0的储备量
     * @return _reserve1 token1的储备量
     * @return _blockTimestampLast 最后更新时间
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev 安全转账函数
     * @param token 代币地址
     * @param to 接收方地址
     * @param value 转账数量
     */
    function _safeTransfer(address token, address to, uint256 value) private {
        // wake-disable-next-line reentrancy
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UniswapV2: TRANSFER_FAILED");
    }

    /**
     * @dev 构造函数
     * 设置工厂合约地址
     */
    constructor() {
        factory = msg.sender;
    }

    /**
     * @dev 初始化交易对（只能由工厂合约调用）
     * @param _token0 第一个代币地址
     * @param _token1 第二个代币地址
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN"); // 只有工厂合约可以调用
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 更新储备量和价格累积值
     * @param balance0 token0的当前余额
     * @param balance1 token1的当前余额
     * @param _reserve0 token0的旧储备量
     * @param _reserve1 token1的旧储备量
     ### 重要作用
        1. 价格预言机 : 维护时间加权平均价格（TWAP），为外部合约提供抗操纵的价格数据
        2. 状态同步 : 确保合约内部储备量与实际代币余额保持一致
        3. 安全保障 : 通过溢出检查防止数值异常
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        // - 确保新的余额不会超过 uint112 的最大值
        // - 这是为了防止储备量溢出，因为储备量使用 uint112 类型存储
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "UniswapV2: OVERFLOW");
        // - 将当前区块时间戳转换为 uint32 类型
        // - 计算自上次更新以来经过的时间
        // - 注意 : 注释说明"溢出是期望的行为"，这是因为时间戳的模运算和差值计算在溢出时仍能正确工作
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // 溢出是期望的行为
        // - timeElapsed > 0 : 确保时间有流逝
        // - _reserve0 != 0 && _reserve1 != 0 : 确保两个储备量都不为零，避免除零错误
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * 永远不会溢出，并且 + 溢出是期望的行为
            // 价格计算 :
            // - price0CumulativeLast : token0 的累积价格（以 token1 计价）
            // - price1CumulativeLast : token1 的累积价格（以 token0 计价）
            // - 使用 UQ112x112 定点数库进行精确的价格计算
            // - encode(_reserve1).uqdiv(_reserve0) 计算 token0 的瞬时价格
            // - 乘以时间间隔得到加权价格，累加到总价格中
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        // 更新合约状态中的储备量
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        // 更新最后更新时间戳
        blockTimestampLast = blockTimestamp;
        // 发射 Sync 事件，通知外部监听者储备量已更新
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev 如果开启了协议手续费，铸造流动性代币给feeTo地址
     * @param _reserve0 token0储备量
     * @param _reserve1 token1储备量
     * @return feeOn 是否开启了协议手续费
     ### 设计亮点
        1. 延迟计算 : 不是每次交换都计算手续费，而是在流动性操作时批量计算
        2. Gas 效率 : 避免频繁的手续费计算，节省 gas
        3. 数学精确性 : 使用平方根计算确保手续费分配的准确性
        4. 灵活控制 : 协议方可以通过设置 feeTo 地址来开启/关闭协议手续费
    ### 数学原理
        协议手续费的计算基于以下观察：
        - 交易手续费会导致 k 值增长
        - k 值的增长率反映了交易活跃度
        - 通过比较当前 k 值和历史 k 值，可以计算出累积的手续费价值
        - 协议收取这部分增值的固定比例（1/6）
        这种设计确保了协议手续费与交易量成正比，同时不影响单次交换的用户体验。
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        // - 从工厂合约获取协议手续费接收地址
        // - 如果 feeTo 不是零地址，说明协议手续费已开启
        // - feeOn 变量记录手续费开启状态
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // 节省gas
        if (feeOn) {
            if (_kLast != 0) {
                // rootK = √(reserve0 × reserve1) : 当前储备量乘积的平方根
                uint256 rootK = Math.sqrt(uint256(_reserve0).mul(_reserve1));
                // rootKLast = √(kLast) : 上次记录的 k 值的平方根
                uint256 rootKLast = Math.sqrt(_kLast);
                // rootK > rootKLast : 只有当前 k 值增长时才收取手续费
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    // liquidity = (totalSupply × (√k - √kLast)) / (5√k + √kLast)
                    // 分子 : totalSupply × (√k - √kLast) 表示由于交易手续费导致的价值增长
                    // 分母 : 5√k + √kLast 确保协议只收取增长价值的 1/6 作为手续费
                    // 结果 : 协议获得相当于总手续费 1/6 的流动性代币
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /**
     * @dev 添加流动性 负责铸造流动性代币（LP Token）
     * 此低级函数应该从执行重要安全检查的合约中调用
     * @param to 接收流动性代币的地址
     * @return liquidity 铸造的流动性代币数量
     ### 数学原理 
        首次流动性计算 使用几何平均数 √(x × y) 的原因：
        - 对两种代币的价值给予相等权重
        - 避免因代币精度差异导致的问题
        - 提供合理的初始价格发现机制 
        后续流动性计算 比例公式确保：
        - 新的流动性提供者按照当前价格添加流动性
        - 不会稀释现有流动性提供者的份额
        - 防止通过不平衡添加进行套利
     */
    function mint(address to) external lock returns (uint256 liquidity) {
        // - 获取交易对的当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // 节省gas
        // - 查询合约当前持有的两种代币余额
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        // - 计算新增的代币数量（当前余额 - 储备量）
        // - 这些新增代币就是用户想要添加的流动性
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        // - 调用 _mintFee 处理协议手续费
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // 必须在 _mintFee 之后获取 totalSupply ，因为手续费可能会增加总供应量
        uint256 _totalSupply = totalSupply; // 局部变量节省gas
        // 流动性计算（核心逻辑）
        if (_totalSupply == 0) { //首次添加流动性
            // 几何平均数 : 使用 √(amount0 × amount1) 计算初始流动性
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            // 最小流动性锁定 : 永久锁定 MINIMUM_LIQUIDITY （1000）代币到零地址
           _mint(address(0), MINIMUM_LIQUIDITY); // 目的 : 防止除零错误和价格操纵攻击
        } else { //后续添加流动性
            // 比例计算 : 根据现有储备量比例计算流动性
            // 公式 : liquidity = min(amount0 × totalSupply / reserve0, amount1 × totalSupply / reserve1)
            // 取最小值 : 确保按照较少的那个代币比例计算，防止套利
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        // 确保计算出的流动性大于 0
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        // 向指定地址铸造流动性代币
        _mint(to, liquidity);

        // - 更新储备量 : 调用 _update 更新储备量和价格累积值
        _update(balance0, balance1, _reserve0, _reserve1);
        // - 更新 kLast : 如果协议手续费开启，记录新的 k 值
        if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0和reserve1是最新的
        // - 发射事件 : 记录铸造事件
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev 销毁流动性代币并返还底层资产的核心函数
     * 用户需要先将流动性代币转入交易对合约，然后调用 burn 函数
     * 此低级函数应该从执行重要安全检查的合约中调用
     * @param to 接收代币的地址
     * @return amount0 返回的token0数量
     * @return amount1 返回的token1数量
     设计原理 :
        - 按比例分配 : 根据用户持有的流动性代币占总供应量的比例来分配底层资产
        - 使用余额而非储备量 : 注释明确说明使用 balance 而不是 reserve ，这样可以包含累积的交易手续费
        - 公平分配 : 确保流动性提供者能够获得其应得的份额，包括累积的手续费收益
     */
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // 节省gas
        address _token0 = token0;                                // 节省gas
        address _token1 = token1;                                // 节省gas
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        // 获取合约自身持有的流动性代币数量（这是用户要销毁的流动性）
        uint256 liquidity = balanceOf[address(this)];

        // 在销毁流动性前先处理协议手续费 
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // 节省gas，必须在_mintFee之后定义 因为手续费可能增加总供应量
        // 按比例计算返还数量（核心逻辑）
        // amount0 = (liquidity × balance0) / totalSupply
        amount0 = liquidity.mul(balance0) / _totalSupply; // 使用余额确保按比例分配
        // amount1 = (liquidity × balance1) / totalSupply
        amount1 = liquidity.mul(balance1) / _totalSupply; // 使用余额确保按比例分配

        // - 确保计算出的返还数量都大于 0
        // - 防止无效的流动性销毁操作
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        // 操作顺序 :
        // 1. 销毁合约持有的流动性代币
        // 2. 安全转账 token0 到指定地址
        // 3. 安全转账 token1 到指定地址
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        // 状态同步 :
        // - 重新查询代币余额（转账后的最新余额）
        // - 调用 _update 更新储备量和价格累积值
        // - 如果协议手续费开启，更新 kLast 值
        // - 发射 Burn 事件记录操作
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0和reserve1是最新的
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev 代币交换
     * 此低级函数应该从执行重要安全检查的合约中调用
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param to 接收代币的地址
     * @param data 传递给回调函数的数据（用于闪电贷）
     * 乐观转账（Optimistic Transfer）：
     *  - 先转出代币，后验证
     *  - 如果验证失败，合约会自动回滚转账
     *  - 这种机制可以防止恶意合约利用转账失败来攻击
     *  - 只需要token输出参数，token输入通过余额变化推断
     * 实际交易流程
     *  - 用户进行代币交换时
     *  // 1. 用户先将代币转入到 Pair 合约
     *  IERC20(token0).transfer(pairAddress, amountIn);
     *  // 2. 然后调用 swap 函数
     *  pair.swap(amount0Out, amount1Out, to, data);
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        // - 确保至少有一个输出量大于0
        // - 获取当前储备量（gas优化）
        // - 确保输出量不超过储备量
        require(amount0Out > 0 || amount1Out > 0, "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // 节省gas
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UniswapV2: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        { // 作用域避免堆栈过深错误
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");
            // 乐观转账 ：先转出代币，后验证
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // 乐观地转移代币
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // 乐观地转移代币

            // - 如果提供了回调数据，执行闪电贷回调
            // - 允许在同一交易中借用代币并执行自定义逻辑
            // wake-disable-next-line reentrancy
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            // 获取当前实际余额
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        // - 计算实际输入量： 实际输入 = 当前余额 - (原储备 - 输出量)
        // - 处理可能的溢出情况
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
        { // 作用域避免堆栈过深错误
            // - 计算调整后的余额（考虑交易手续费）
            // - 确保新的余额满足k值公式（防止价格操纵）
            // - 核心AMM机制 ：验证 x * y ≥ k
            // - 扣除0.3%手续费： (balance - fee) * (balance - fee) ≥ k
            // - 使用1000倍放大避免精度损失
            // 交易手续费为0.3%，通过调整后余额计算实现：
            //   - balance * 1000 - amountIn * 3 相当于 balance * (1 - 0.003)
            uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(_reserve1).mul(1000**2), "UniswapV2: K");
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 强制余额匹配储备量
     * @param to 接收多余代币的地址
     - 核心功能 ：清理合约中超出储备量的代币
     - 使用场景 ：处理意外转入、通胀代币、合约维护
     - 设计特点 ：安全、高效、透明
     - 与sync对比 ：移除多余 vs 同步储备
     */
    function skim(address to) external lock {
        address _token0 = token0; // 节省gas
        address _token1 = token1; // 节省gas
        // 多余代币数量 = 当前实际余额 - 记录的储备量
        // excessAmount = actualBalance - recordedReserve
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /**
     * @dev 强制储备量匹配余额
     */
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}