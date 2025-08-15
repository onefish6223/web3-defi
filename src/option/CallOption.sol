// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 导入OpenZeppelin合约库
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";           // ERC20标准实现
import "@openzeppelin/contracts/access/Ownable.sol";              // 所有权管理
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";       // 重入攻击防护
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";          // ERC20接口
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // 安全的ERC20操作

/**
 * @title CallOption - 看涨期权Token合约
 * @dev 基于ERC20标准的看涨期权合约，支持完整的期权生命周期管理
 * 
 * 核心功能：
 * 1. 期权发行：项目方存入ETH，按1:1比例铸造期权Token
 * 2. 期权交易：期权Token可在二级市场自由交易（通过ERC20标准）
 * 3. 期权行权：到期日用户可用USDT按行权价购买ETH
 * 4. 期权过期：过期后项目方可赎回未行权的ETH
 * 
 * 安全特性：
 * - 重入攻击防护（ReentrancyGuard）
 * - 权限控制（Ownable）
 * - 安全的代币转账（SafeERC20）
 * - 严格的时间窗口控制
 * - 完整的余额和授权检查
 */
contract CallOption is ERC20, Ownable, ReentrancyGuard {
    
    // ============ 期权核心参数 ============
    
    /// @notice 行权价格，以USDT为单位（6位小数精度）
    /// @dev 用户行权时需要支付的USDT数量 = 期权数量 * 行权价格 / 1e18
    uint256 public strikePrice;
    
    /// @notice 期权到期日期（Unix时间戳）
    /// @dev 只有在到期日当天（24小时内）才能行权
    uint256 public expirationDate;
    
    /// @notice 标的资产创建时的参考价格（6位小数精度）
    /// @dev 仅用于参考，不影响实际行权计算，可由项目方更新
    uint256 public underlyingPrice;
    
    /// @notice 标的资产地址
    /// @dev 当前版本固定为ETH，使用address(0)表示原生ETH
    address public underlyingAsset;
    
    /// @notice USDT代币合约地址
    /// @dev 用户行权时需要支付的稳定币，必须是标准的ERC20代币
    address public usdtToken;
    
    // ============ 期权状态管理 ============
    
    /// @notice 期权是否已过期标志
    /// @dev 一旦设置为true，将无法再进行任何操作，只能紧急提取
    bool public isExpired;
    
    /// @notice 项目方总共存入的ETH数量（18位小数精度）
    /// @dev 用于跟踪合约中应有的ETH总量，便于审计和验证
    uint256 public totalUnderlyingDeposited;
    
    // ============ 事件定义 ============
    
    /// @notice 期权发行事件
    /// @param issuer 发行者地址（项目方）
    /// @param underlyingAmount 存入的ETH数量
    /// @param optionTokens 铸造的期权Token数量
    event OptionIssued(address indexed issuer, uint256 underlyingAmount, uint256 optionTokens);
    
    /// @notice 期权行权事件
    /// @param exerciser 行权者地址
    /// @param optionTokens 行权的期权Token数量
    /// @param underlyingReceived 获得的ETH数量
    event OptionExercised(address indexed exerciser, uint256 optionTokens, uint256 underlyingReceived);
    
    /// @notice 期权过期事件
    /// @param underlyingRedeemed 项目方赎回的ETH数量
    event OptionExpired(uint256 underlyingRedeemed);
    
    /// @notice 标的资产价格更新事件
    /// @param newPrice 新的价格
    event UnderlyingPriceUpdated(uint256 newPrice);
    
    // ============ 构造函数 ============
    
    /**
     * @notice 构造函数 - 初始化看涨期权合约
     * @dev 创建期权合约时确定所有核心参数，部署后不可修改
     * 
     * @param _name 期权Token名称（如："ETH Call Option 2024-12-31"）
     * @param _symbol 期权Token符号（如："ETH-CALL-1231"）
     * @param _strikePrice 行权价格，以USDT为单位，6位小数精度（如：3000000000表示3000 USDT）
     * @param _expirationDate 到期日期，Unix时间戳格式，必须大于当前时间
     * @param _underlyingPrice 标的资产初始价格，6位小数精度，仅供参考
     * @param _underlyingAsset 标的资产地址，当前版本固定为address(0)表示ETH
     * @param _usdtToken USDT代币合约地址，必须是有效的ERC20合约
     * 
     * 要求：
     * - 到期日期必须在未来
     * - 行权价格必须大于0
     * - 标的资产价格必须大于0
     * - USDT代币地址不能为零地址
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _strikePrice,
        uint256 _expirationDate,
        uint256 _underlyingPrice,
        address _underlyingAsset,
        address _usdtToken
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        // 参数验证
        require(_expirationDate > block.timestamp, "Expiration date must be in the future");
        require(_strikePrice > 0, "Strike price must be greater than 0");
        require(_underlyingPrice > 0, "Underlying price must be greater than 0");
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        
        // 初始化期权参数
        strikePrice = _strikePrice;
        expirationDate = _expirationDate;
        underlyingPrice = _underlyingPrice;
        underlyingAsset = _underlyingAsset;
        usdtToken = _usdtToken;
        isExpired = false;
    }
    
    // ============ 核心功能函数 ============
    
    /**
     * @notice 发行期权Token（仅限项目方）
     * @dev 项目方存入ETH，按1:1比例铸造期权Token，用于后续销售给用户
     * 
     * 业务逻辑：
     * 1. 项目方向合约转入ETH作为标的资产
     * 2. 合约按1:1比例铸造期权Token给项目方
     * 3. 项目方可将期权Token出售给用户或在DEX上创建流动性
     * 4. 用户持有期权Token后可在到期日行权
     * 
     * 安全检查：
     * - 只有合约所有者（项目方）可以调用
     * - 期权未过期
     * - 未到达到期日期
     * - 必须转入ETH（msg.value > 0）
     * - 防重入攻击保护
     * 
     * @custom:example
     * 项目方转入10 ETH，将铸造10个期权Token（精度为18位小数）
     */
    function issueOptions() external payable onlyOwner nonReentrant {
        // 状态检查
        require(!isExpired, "Options have expired");
        require(block.timestamp < expirationDate, "Cannot issue after expiration");
        require(msg.value > 0, "Must deposit ETH");
        
        // 计算发行的期权Token数量（1:1比例，保持18位小数精度）
        uint256 optionTokensToMint = msg.value;
        
        // 更新合约状态
        totalUnderlyingDeposited += msg.value;
        
        // 铸造期权Token给项目方
        _mint(owner(), optionTokensToMint);
        
        // 触发事件
        emit OptionIssued(owner(), msg.value, optionTokensToMint);
    }
    
    /**
     * @notice 行权功能（用户调用）
     * @dev 用户在到期日当天用USDT按行权价购买ETH，同时销毁期权Token
     * 
     * 业务逻辑：
     * 1. 用户在到期日当天（24小时窗口期）可以行权
     * 2. 用户需要支付：期权数量 × 行权价格 的USDT
     * 3. 用户获得：等量的ETH（1:1比例）
     * 4. 用户的期权Token被销毁
     * 5. 项目方获得用户支付的USDT
     * 
     * 时间窗口：
     * - 只能在到期日当天行权（expirationDate ~ expirationDate + 24小时）
     * - 超过24小时后期权自动失效
     * 
     * 计算公式：
     * - 需要支付的USDT = optionAmount × strikePrice ÷ 1e18
     * - 获得的ETH = optionAmount（1:1比例）
     * 
     * 安全检查：
     * - 期权未过期
     * - 在有效行权时间窗口内
     * - 用户有足够的期权Token
     * - 用户有足够的USDT余额和授权
     * - 合约有足够的ETH余额
     * - 防重入攻击保护
     * 
     * @param optionAmount 要行权的期权Token数量（18位小数精度）
     * 
     * @custom:example
     * 用户持有5个期权Token，行权价格为3000 USDT
     * 需要支付：5 × 3000 = 15000 USDT
     * 获得：5 ETH
     */
    function exerciseOption(uint256 optionAmount) external nonReentrant {
        // 基础状态检查
        require(!isExpired, "Options have expired");
        require(block.timestamp >= expirationDate, "Cannot exercise before expiration date");
        require(block.timestamp <= expirationDate + 1 days, "Exercise period has ended");
        require(optionAmount > 0, "Option amount must be greater than 0");
        require(balanceOf(msg.sender) >= optionAmount, "Insufficient option tokens");
        
        // 计算需要支付的USDT数量
        // optionAmount是18位小数(ETH), strikePrice是6位小数(USDT)
        // 计算结果是6位小数(USDT)
        uint256 usdtRequired = (optionAmount * strikePrice) / 1e18;
        
        // 检查用户USDT余额和授权
        IERC20 usdt = IERC20(usdtToken);
        require(usdt.balanceOf(msg.sender) >= usdtRequired, "Insufficient USDT balance");
        require(usdt.allowance(msg.sender, address(this)) >= usdtRequired, "Insufficient USDT allowance");
        
        // 检查合约ETH余额
        require(address(this).balance >= optionAmount, "Insufficient underlying asset in contract");
        
        // 执行交易（遵循Checks-Effects-Interactions模式）
        
        // 1. Effects: 先执行状态变更，销毁期权Token
        _burn(msg.sender, optionAmount);
        
        // 2. Interactions: 再执行外部调用
        // 转入USDT到合约
        SafeERC20.safeTransferFrom(usdt, msg.sender, address(this), usdtRequired);
        
        // 转出ETH给用户
        payable(msg.sender).transfer(optionAmount);
        
        // 触发事件
        emit OptionExercised(msg.sender, optionAmount, optionAmount);
    }
    
    /**
     * @notice 期权过期处理（仅限项目方）
     * @dev 在行权期结束后，项目方可以将所有剩余资产赎回，并标记期权为过期状态
     * 
     * 业务逻辑：
     * 1. 只能在行权期结束后调用（到期日+24小时后）
     * 2. 将合约标记为过期状态，禁止后续所有操作
     * 3. 赎回所有剩余的ETH给项目方（未被行权的部分）
     * 4. 赎回所有USDT给项目方（用户行权支付的费用）
     * 5. 此时所有未行权的期权Token将永久失效
     * 
     * 时间要求：
     * - 必须在行权期结束后才能调用（expirationDate + 24小时后）
     * - 确保用户有充分时间行权
     * 
     * 资产处理：
     * - 剩余ETH = 初始存入ETH - 已行权ETH
     * - 获得USDT = 用户行权支付的总USDT
     * 
     * 安全检查：
     * - 只有合约所有者（项目方）可以调用
     * - 期权尚未过期（避免重复调用）
     * - 行权期已结束
     * - 防重入攻击保护
     * 
     * @custom:example
     * 假设项目方存入100 ETH，用户行权了30 ETH并支付90000 USDT
     * 过期后项目方将获得：70 ETH + 90000 USDT
     */
    function expireOptions() external onlyOwner nonReentrant {
        // 状态检查
        require(!isExpired, "Options already expired");
        require(block.timestamp > expirationDate + 1 days, "Exercise period not ended yet");
        
        // 标记为过期状态
        isExpired = true;
        
        // 赎回剩余的ETH给项目方
        uint256 remainingETH = address(this).balance;
        if (remainingETH > 0) {
            payable(owner()).transfer(remainingETH);
        }
        
        // 转出合约中的USDT给项目方（用户行权支付的费用）
        IERC20 usdt = IERC20(usdtToken);
        uint256 usdtBalance = usdt.balanceOf(address(this));
        if (usdtBalance > 0) {
            SafeERC20.safeTransfer(usdt, owner(), usdtBalance);
        }
        
        // 触发事件
        emit OptionExpired(remainingETH);
    }
    
    // ============ 管理功能函数 ============
    
    /**
     * @notice 更新标的资产参考价格（仅限项目方）
     * @dev 更新ETH的参考价格，仅用于信息展示，不影响实际行权计算
     * 
     * 说明：
     * - 此价格仅供参考，用于前端展示或数据分析
     * - 不影响期权的行权价格（strikePrice）
     * - 不影响用户行权时的实际计算
     * - 项目方可根据市场情况随时更新
     * 
     * 用途：
     * - 前端界面显示当前ETH价格
     * - 计算期权的内在价值（当前价格 - 行权价格）
     * - 数据分析和统计
     * 
     * @param newPrice 新的ETH价格（6位小数精度，与USDT相同）
     * 
     * @custom:example
     * 当ETH市场价格为3500 USDT时，调用updateUnderlyingPrice(3500000000)
     */
    function updateUnderlyingPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be greater than 0");
        underlyingPrice = newPrice;
        emit UnderlyingPriceUpdated(newPrice);
    }
    
    // ============ 查询功能函数 ============
    
    /**
     * @notice 获取期权完整信息
     * @dev 一次性返回期权合约的所有关键参数和状态信息
     * 
     * 返回信息包括：
     * - 期权基本参数（行权价格、到期日期等）
     * - 资产地址信息
     * - 期权当前状态
     * - 供应量和存款统计
     * 
     * @return _strikePrice 行权价格（6位小数精度）
     * @return _expirationDate 到期日期（Unix时间戳）
     * @return _underlyingPrice 当前标的资产参考价格（6位小数精度）
     * @return _underlyingAsset 标的资产地址（ETH为address(0)）
     * @return _usdtToken USDT代币合约地址
     * @return _isExpired 是否已过期
     * @return _totalSupply 当前期权Token总供应量
     * @return _totalUnderlyingDeposited 项目方总共存入的ETH数量
     * 
     * @custom:usage 前端可调用此函数获取期权的完整状态信息
     */
    function getOptionDetails() external view returns (
        uint256 _strikePrice,
        uint256 _expirationDate,
        uint256 _underlyingPrice,
        address _underlyingAsset,
        address _usdtToken,
        bool _isExpired,
        uint256 _totalSupply,
        uint256 _totalUnderlyingDeposited
    ) {
        return (
            strikePrice,
            expirationDate,
            underlyingPrice,
            underlyingAsset,
            usdtToken,
            isExpired,
            totalSupply(),
            totalUnderlyingDeposited
        );
    }
    
    /**
     * @notice 检查期权是否可以行权
     * @dev 判断当前时间是否在有效行权窗口期内
     * 
     * 行权条件：
     * 1. 期权未过期（isExpired = false）
     * 2. 已到达到期日（block.timestamp >= expirationDate）
     * 3. 在24小时行权窗口内（block.timestamp <= expirationDate + 1 days）
     * 
     * @return bool 如果可以行权返回true，否则返回false
     * 
     * @custom:usage 前端可调用此函数判断是否显示行权按钮
     */
    function canExercise() external view returns (bool) {
        return !isExpired && 
               block.timestamp >= expirationDate && 
               block.timestamp <= expirationDate + 1 days;
    }
    
    /**
     * @notice 计算行权所需的USDT数量
     * @dev 根据期权数量和行权价格计算用户需要支付的USDT总额
     * 
     * 计算公式：
     * USDT数量 = 期权Token数量 × 行权价格 ÷ 1e18
     * 
     * 精度说明：
     * - 输入：optionAmount（18位小数，ETH精度）
     * - 参数：strikePrice（6位小数，USDT精度）
     * - 输出：USDT数量（6位小数，USDT精度）
     * 
     * @param optionAmount 要行权的期权Token数量（18位小数精度）
     * @return uint256 需要支付的USDT数量（6位小数精度）
     * 
     * @custom:example
     * 行权5个期权Token，行权价格3000 USDT
     * 计算：5 * 1e18 * 3000 * 1e6 / 1e18 = 15000 * 1e6 = 15000 USDT
     */
    function calculateExerciseCost(uint256 optionAmount) external view returns (uint256) {
        // optionAmount是18位小数(ETH), strikePrice是6位小数(USDT)
        // 计算结果是6位小数(USDT)
        return (optionAmount * strikePrice) / 1e18;
    }
    
    // ============ 紧急功能函数 ============
    
    /**
     * @notice 紧急提取函数（仅限项目方，仅在期权过期后）
     * @dev 在期权过期后，如果expireOptions()函数出现问题，可使用此函数紧急提取资产
     * 
     * 使用场景：
     * - expireOptions()函数执行失败
     * - 合约出现异常状态需要紧急处理
     * - 作为expireOptions()的备用方案
     * 
     * 安全限制：
     * - 只有合约所有者可以调用
     * - 只能在期权过期后调用
     * - 确保用户权益不受损害
     * 
     * 提取内容：
     * - 合约中的所有ETH余额
     * - 合约中的所有USDT余额
     * 
     * @custom:security 此函数仅在紧急情况下使用，正常情况下应使用expireOptions()
     */
    function emergencyWithdraw() external onlyOwner {
        require(isExpired, "Can only withdraw after expiration");
        
        // 提取所有ETH余额
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }
        
        // 提取所有USDT余额
        IERC20 usdt = IERC20(usdtToken);
        uint256 usdtBalance = usdt.balanceOf(address(this));
        if (usdtBalance > 0) {
            SafeERC20.safeTransfer(usdt, owner(), usdtBalance);
        }
    }
    
    // ============ 特殊函数 ============
    
    /**
     * @notice 接收ETH的回调函数
     * @dev 允许合约接收ETH转账，主要用于项目方发行期权时存入ETH
     * 
     * 说明：
     * - 此函数在有人向合约直接转账ETH时被调用
     * - 不执行任何特殊逻辑，仅接收ETH
     * - 项目方通过issueOptions()函数发行期权时会触发此函数
     */
    receive() external payable {
        // 允许接收ETH，无需额外逻辑
    }
}