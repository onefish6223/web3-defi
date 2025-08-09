// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MemeToken.sol";
import "../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../uniswapv2/interfaces/IUniswapV2Factory.sol";
import "../uniswapv2/libraries/UniswapV2Library.sol";

/**
 * @title MemeFactory
 * @dev Meme代币发射平台工厂合约，使用最小代理模式创建代币
 */
contract MemeFactory is Ownable, ReentrancyGuard {
    using Clones for address;
    using SafeERC20 for IERC20;
    
    address public immutable memeTokenImplementation;  // 代币模板合约地址
    uint256 public constant PLATFORM_FEE_RATE = 500;  // 平台费率 5% (1/10000)
    IUniswapV2Router02 public immutable uniswapRouter;  // Uniswap V2 路由器地址
    
    // 存储每个代币的信息
    struct MemeInfo {
        string symbol;
        uint256 totalSupply;
        uint256 perMint;
        uint256 price;
        address creator;
        bool exists;
    }
    
    mapping(address => MemeInfo) public memeTokens;  // 代币地址 => 代币信息
    address[] public allMemeTokens;                   // 所有创建的代币地址
    
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 payment,
        uint256 platformFee,
        uint256 creatorFee
    );
    
    constructor(address _uniswapRouter) Ownable(msg.sender) {
        require(_uniswapRouter != address(0), "Invalid router address");
        // 部署代币模板合约
        memeTokenImplementation = address(new MemeToken());
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }
    
    /**
     * @dev 部署新的Meme代币
     * @param symbol 代币符号
     * @param totalSupply 总发行量
     * @param perMint 每次铸造数量
     * @param price 每个代币价格（wei）
     * @return tokenAddress 部署的代币合约地址
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external nonReentrant returns (address tokenAddress) {
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint cannot exceed total supply");
        
        // 使用最小代理模式克隆代币合约
        tokenAddress = memeTokenImplementation.clone();
        
        // 存储代币信息（在外部调用之前更新状态）
        memeTokens[tokenAddress] = MemeInfo({
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            creator: msg.sender,
            exists: true
        });
        
        allMemeTokens.push(tokenAddress);
        
        // 初始化代币合约
        // wake-disable-next-line
        MemeToken(tokenAddress).initialize(
            symbol,  // name
            symbol,  // symbol
            totalSupply,
            perMint,
            price,
            msg.sender,
            address(this)
        );
        
        emit MemeDeployed(
            tokenAddress,
            msg.sender,
            symbol,
            totalSupply,
            perMint,
            price
        );
        
        return tokenAddress;
    }
    
    /**
     * @dev 铸造Meme代币
     * @param tokenAddr 代币合约地址
     */
    function mintMeme(address tokenAddr) external payable nonReentrant {
        require(memeTokens[tokenAddr].exists, "Token does not exist");
        
        MemeToken memeToken = MemeToken(tokenAddr);
        MemeInfo memory info = memeTokens[tokenAddr];
        info; // silence unused variable warning
        
        require(memeToken.canMint(), "Cannot mint more tokens");
        
        // 计算总支付金额：price是每个代币的价格，perMint是代币数量（包含18位小数）
        uint256 totalPayment = (info.price * info.perMint) / 1e18;
        require(msg.value >= totalPayment, "Insufficient payment");
        uint256 platformFee = totalPayment * PLATFORM_FEE_RATE / 10000;  // 5%给平台
        uint256 creatorFee = totalPayment - platformFee;         // 95%给创建者
        
        // 先分配费用（避免在mint后进行外部调用）
        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }
        if (creatorFee > 0) {
            payable(info.creator).transfer(creatorFee);
        }
        
        // 退还多余的ETH
        if (msg.value > totalPayment) {
            payable(msg.sender).transfer(msg.value - totalPayment);
        }
        
        // 最后铸造代币（外部调用放在最后）
        // wake-disable-next-line
        require(memeToken.mint(msg.sender), "Mint failed");
        
        emit MemeMinted(
            tokenAddr,
            msg.sender,
            info.perMint,
            totalPayment,
            platformFee,
            creatorFee
        );
    }
    
    /**
     * @dev 获取所有创建的代币数量
     */
    function getAllMemeTokensCount() external view returns (uint256) {
        return allMemeTokens.length;
    }
    
    /**
     * @dev 获取指定范围的代币地址
     * @param start 起始索引
     * @param end 结束索引
     */
    function getMemeTokens(uint256 start, uint256 end) 
        external 
        view 
        returns (address[] memory) 
    {
        require(start <= end, "Invalid range");
        require(end < allMemeTokens.length, "End index out of bounds");
        
        address[] memory tokens = new address[](end - start + 1);
        for (uint256 i = start; i <= end; i++) {
            tokens[i - start] = allMemeTokens[i];
        }
        return tokens;
    }
    
    /**
     * @dev 获取代币信息
     * @param tokenAddr 代币地址
     */
    function getMemeInfo(address tokenAddr) 
        external 
        view 
        returns (MemeInfo memory) 
    {
        require(memeTokens[tokenAddr].exists, "Token does not exist");
        return memeTokens[tokenAddr];
    }
    
    /**
     * @dev 检查代币是否存在
     * @param tokenAddr 代币地址
     */
    function isMemeToken(address tokenAddr) external view returns (bool) {
        return memeTokens[tokenAddr].exists;
    }
    
    /**
     * @dev 铸造Meme代币并添加流动性
     * @param tokenAddr 代币合约地址
     * @param liquidityETHAmount 用于添加流动性的ETH数量
     * @param deadline 交易截止时间
     */
    function mintMemeAndAddLiquidity(
        address tokenAddr,
        uint256 liquidityETHAmount,
        uint256 deadline
    ) external payable nonReentrant {
        require(memeTokens[tokenAddr].exists, "Token does not exist");
        require(liquidityETHAmount > 0, "Liquidity ETH amount must be greater than 0");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        MemeInfo memory info = memeTokens[tokenAddr];
        
        // 计算铸造支付金额
        uint256 mintPayment = info.price * info.perMint / 1e18;
        
        // 根据mint价格计算流动性所需的代币数量
        uint256 liquidityTokenAmount = (liquidityETHAmount * 1e18) / info.price;
        
        // 确保流动性代币数量不超过每次铸造的数量
        if (liquidityTokenAmount > info.perMint) {
            liquidityTokenAmount = info.perMint;
        }
        
        // 验证总支付金额
        uint256 totalRequired = mintPayment + liquidityETHAmount;
        require(msg.value >= totalRequired, "Insufficient payment for mint and liquidity");
        
        // 执行铸造和费用处理
        _handleMintAndFees(tokenAddr, info);
        
        // 添加流动性
        _addLiquidityForUser(tokenAddr, info, liquidityETHAmount, liquidityTokenAmount, deadline, mintPayment);
        
        // 退还多余的ETH
        if (msg.value > totalRequired) {
            payable(msg.sender).transfer(msg.value - totalRequired);
        }
    }
    
    /**
     * @dev 内部函数：处理铸造（不分配费用）
     */
    function _handleMintAndFees(
        address tokenAddr,
        // wake-disable-next-line
        MemeInfo memory /* info */
    ) internal {
        MemeToken memeToken = MemeToken(tokenAddr);
        require(memeToken.canMint(), "Cannot mint more tokens");
        
        // 铸造代币给合约
        // wake-disable-next-line
        require(memeToken.mint(address(this)), "Mint failed");
    }
    
    /**
     * @dev 内部函数：分配费用
     */
    function _distributeFees(
        uint256 mintPayment,
        address creator
    ) internal {
        // 计算费用分配
        uint256 platformFee = mintPayment * PLATFORM_FEE_RATE / 10000;
        uint256 creatorFee = mintPayment - platformFee;
        
        // 分配铸造费用
        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }
        if (creatorFee > 0) {
            payable(creator).transfer(creatorFee);
        }
    }
    
    /**
     * @dev 内部函数：为用户添加流动性
     */
    function _addLiquidityForUser(
        address tokenAddr,
        MemeInfo memory info,
        uint256 liquidityETHAmount,
        uint256 liquidityTokenAmount,
        uint256 deadline,
        uint256 mintPayment
    ) internal {
        // 合约授权路由器使用代币
        IERC20(tokenAddr).forceApprove(address(uniswapRouter), liquidityTokenAmount);
        
        // 设置滑点保护（5%）
        uint256 amountTokenMin = liquidityTokenAmount * 95 / 100;
        uint256 amountETHMin = liquidityETHAmount * 95 / 100;
        
        // 添加流动性
        try uniswapRouter.addLiquidityETH{value: liquidityETHAmount}(
            tokenAddr,
            liquidityTokenAmount,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            deadline
        ) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
            // 添加流动性成功后分配费用
            _distributeFees(mintPayment, info.creator);
            
            // 发出事件
            _emitEvents(tokenAddr, info, mintPayment, amountToken, amountETH, liquidity);
        } catch {
            // 如果添加流动性失败，将代币转给用户并退还流动性ETH
            IERC20(tokenAddr).safeTransfer(msg.sender, liquidityTokenAmount);
            payable(msg.sender).transfer(liquidityETHAmount);
            revert("Failed to add liquidity");
        }
        
        // 如果有剩余的代币，转给用户
        uint256 remainingTokens = IERC20(tokenAddr).balanceOf(address(this));
        if (remainingTokens > 0) {
            IERC20(tokenAddr).safeTransfer(msg.sender, remainingTokens);
        }
    }
    
    /**
     * @dev 内部函数：发出相关事件
     */
    function _emitEvents(
        address tokenAddr,
        MemeInfo memory info,
        uint256 mintPayment,
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    ) internal {
        uint256 platformFee = mintPayment * PLATFORM_FEE_RATE / 10000;
        uint256 creatorFee = mintPayment - platformFee;
        
        emit MemeMinted(
            tokenAddr,
            msg.sender,
            info.perMint,
            mintPayment,
            platformFee,
            creatorFee
        );
        
        emit LiquidityAdded(
            tokenAddr,
            msg.sender,
            amountToken,
            amountETH,
            liquidity
        );
    }
    
    // 新增事件
    event LiquidityAdded(
        address indexed tokenAddress,
        address indexed user,
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );
    
    event MemeBought(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 amountETH,
        uint256 amountTokens
    );

    /**
     * @dev 通过Uniswap购买Meme代币（当价格优于起始价格时）
     * @param tokenAddr 代币合约地址
     * @param amountOutMin 最小输出代币数量（滑点保护）
     * @param deadline 交易截止时间
     */
    function buyMeme(
        address tokenAddr,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable nonReentrant {
        require(memeTokens[tokenAddr].exists, "Token does not exist");
        require(msg.value > 0, "Must send ETH to buy tokens");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        // 验证价格和流动性
        _validatePriceAndLiquidity(tokenAddr);
        
        // 执行购买
        _executeBuy(tokenAddr, amountOutMin, deadline);
    }
    
    /**
     * @dev 内部函数：验证价格和流动性
     */
    function _validatePriceAndLiquidity(address tokenAddr) internal view {
        MemeInfo memory info = memeTokens[tokenAddr];
        
        // 检查是否存在交易对
        address factory = uniswapRouter.factory();
        address weth = uniswapRouter.WETH();
        address pair = IUniswapV2Factory(factory).getPair(tokenAddr, weth);
        require(pair != address(0), "Trading pair does not exist");
        
        // 获取当前储备量
        (uint256 reserveToken, uint256 reserveETH) = UniswapV2Library.getReserves(
            factory, 
            tokenAddr, 
            weth
        );
        require(reserveToken > 0 && reserveETH > 0, "Insufficient liquidity");
        
        // 计算当前市场价格（每个代币需要多少ETH）
        uint256 currentPrice = (reserveETH * 1e18) / reserveToken;
        
        // 检查当前价格是否优于起始价格（当前价格应该低于起始价格才能购买）
        require(currentPrice < info.price, "Current price is not better than initial price");
    }
    
    /**
     * @dev 内部函数：执行购买
     */
    function _executeBuy(
        address tokenAddr,
        uint256 amountOutMin,
        uint256 deadline
    ) internal {
        // 构建交换路径：ETH -> Token
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;
        
        // 记录购买前的代币余额
        uint256 balanceBefore = IERC20(tokenAddr).balanceOf(msg.sender);
        
        // 通过Uniswap购买代币
        // wake-disable-next-line
        uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
        
        // 计算实际购买到的代币数量
        uint256 tokensBought = IERC20(tokenAddr).balanceOf(msg.sender) - balanceBefore;
        
        emit MemeBought(
            tokenAddr,
            msg.sender,
            msg.value,
            tokensBought
        );
    }

    /**
     * @dev 获取代币当前市场价格
     * @param tokenAddr 代币合约地址
     * @return currentPrice 当前价格（每个代币需要多少ETH，以wei为单位）
     * @return initialPrice 起始价格（每个代币需要多少ETH，以wei为单位）
     * @return isPriceBetter 当前价格是否优于起始价格
     */
    function getTokenPrice(address tokenAddr) 
        external 
        view 
        returns (uint256 currentPrice, uint256 initialPrice, bool isPriceBetter) 
    {
        require(memeTokens[tokenAddr].exists, "Token does not exist");
        
        MemeInfo memory info = memeTokens[tokenAddr];
        initialPrice = info.price;
        
        // 检查是否存在交易对
        address factory = uniswapRouter.factory();
        address weth = uniswapRouter.WETH();
        address pair = IUniswapV2Factory(factory).getPair(tokenAddr, weth);
        
        if (pair == address(0)) {
            // 交易对不存在，返回初始价格
            currentPrice = initialPrice;
            isPriceBetter = false;
            return (currentPrice, initialPrice, isPriceBetter);
        }
        
        // 获取当前储备量
        (uint256 reserveToken, uint256 reserveETH) = UniswapV2Library.getReserves(factory, tokenAddr, weth);
        
        if (reserveToken > 0 && reserveETH > 0) {
            // 计算当前市场价格（每个代币需要多少ETH）
            currentPrice = (reserveETH * 1e18) / reserveToken;
            isPriceBetter = currentPrice < initialPrice;
        } else {
            // 流动性不足，返回初始价格
            currentPrice = initialPrice;
            isPriceBetter = false;
        }
    }

    /**
     * @dev 紧急提取合约中的ETH（仅所有者）
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
}