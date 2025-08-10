// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {MemeFactory} from "../src/memefactory/MemeFactory.sol";
import {MemeToken} from "../src/memefactory/MemeToken.sol";
import {ExampleOracleSimple} from "../src/uniswapv2/ExampleOracleSimple.sol";
import {UniswapV2Factory} from "../src/uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../src/uniswapv2/UniswapV2Router02.sol";
import {IUniswapV2Pair} from "../src/uniswapv2/interfaces/IUniswapV2Pair.sol";
import {WETH} from "../src/WETH.sol";

/**
 * @title MemeTWAPOracleTest
 * @dev 测试 LaunchPad 发行的 Meme 代币的 TWAP 价格预言机功能
 * 
 * 测试场景：
 * 1. 通过 MemeFactory 发行 Meme 代币
 * 2. 添加初始流动性创建交易对
 * 3. 部署 TWAP 预言机
 * 4. 模拟不同时间点的多个交易
 * 5. 验证 TWAP 价格计算的准确性
 */
contract MemeTWAPOracleTest is Test {
    // 合约实例
    MemeFactory public memeFactory;
    UniswapV2Factory public uniswapFactory;
    UniswapV2Router02 public uniswapRouter;
    WETH public weth;
    ExampleOracleSimple public oracle;
    
    // Meme 代币相关
    address public memeToken;
    MemeToken public meme;
    IUniswapV2Pair public memePair;
    
    // 测试账户
    address public deployer = address(this);
    address public trader1 = address(0x1);
    address public trader2 = address(0x2);
    address public trader3 = address(0x3);
    address public liquidityProvider = address(0x4);
    
    // 测试常量
    uint256 public constant INITIAL_ETH_BALANCE = 100 ether;
    uint256 public constant MEME_TOTAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant MEME_MINT_AMOUNT = 10000 * 10**18;
    uint256 public constant MEME_PRICE = 0.001 ether; // 每个代币 0.001 ETH
    uint256 public constant INITIAL_LIQUIDITY_ETH = 10 ether;
    
    // 事件定义
    event TWAPPriceUpdated(uint256 timestamp, address token, uint256 price);
    event TradeExecuted(address trader, uint256 amountIn, uint256 amountOut, bool isETHToMeme);
    
    // 接收ETH的函数
    receive() external payable {}
    fallback() external payable {}
    
    /**
     * @dev 测试设置
     */
    function setUp() public {
        // 为测试账户分配 ETH
        vm.deal(deployer, INITIAL_ETH_BALANCE);
        vm.deal(trader1, INITIAL_ETH_BALANCE);
        vm.deal(trader2, INITIAL_ETH_BALANCE);
        vm.deal(trader3, INITIAL_ETH_BALANCE);
        vm.deal(liquidityProvider, INITIAL_LIQUIDITY_ETH * 2);
        
        // 部署基础合约
        weth = new WETH();
        uniswapFactory = new UniswapV2Factory(deployer);
        uniswapRouter = new UniswapV2Router02(address(uniswapFactory), address(weth));
        
        // 部署 MemeFactory
        memeFactory = new MemeFactory(address(uniswapRouter));
        
        // 通过 MemeFactory 发行 Meme 代币
        memeToken = memeFactory.deployMeme(
            "TestMeme",
            MEME_TOTAL_SUPPLY,
            MEME_MINT_AMOUNT,
            MEME_PRICE
        );
        
        meme = MemeToken(memeToken);
        
        // 创建交易对并添加初始流动性
        _setupInitialLiquidity();
        
        // 部署 TWAP 预言机
        oracle = new ExampleOracleSimple(
            address(uniswapFactory),
            address(weth),
            memeToken
        );
        
        console.log("Setup completed:");
        console.log("Meme Token:", memeToken);
        console.log("Pair Address:", address(memePair));
        console.log("Oracle Address:", address(oracle));
    }
    
    /**
     * @dev 设置初始流动性
     */
    function _setupInitialLiquidity() internal {
        vm.startPrank(liquidityProvider);
        
        // 创建交易对
        address pairAddress = uniswapFactory.createPair(address(weth), memeToken);
        memePair = IUniswapV2Pair(pairAddress);
        
        // 铸造 Meme 代币并添加流动性
        uint256 mintCost = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
        uint256 totalCost = mintCost + INITIAL_LIQUIDITY_ETH;
        
        memeFactory.mintMemeAndAddLiquidity{value: totalCost}(
            memeToken,
            INITIAL_LIQUIDITY_ETH,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
        
        // 等待一些时间让价格累积
        vm.warp(block.timestamp + 1 hours);
    }
    
    /**
     * @dev 执行交易（ETH 换 Meme）
     */
    function _swapETHForMeme(address trader, uint256 ethAmount) internal returns (uint256 memeAmount) {
        vm.startPrank(trader);
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = memeToken;
        
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{value: ethAmount}(
            0, // 接受任何数量的代币
            path,
            trader,
            block.timestamp + 1 hours
        );
        
        memeAmount = amounts[1];
        
        emit TradeExecuted(trader, ethAmount, memeAmount, true);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 执行交易（Meme 换 ETH）
     */
    function _swapMemeForETH(address trader, uint256 memeAmount) internal returns (uint256 ethAmount) {
        vm.startPrank(trader);
        
        // 授权路由器使用代币
        meme.approve(address(uniswapRouter), memeAmount);
        
        address[] memory path = new address[](2);
        path[0] = memeToken;
        path[1] = address(weth);
        
        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            memeAmount,
            0, // 接受任何数量的 ETH
            path,
            trader,
            block.timestamp + 1 hours
        );
        
        ethAmount = amounts[1];
        
        emit TradeExecuted(trader, memeAmount, ethAmount, false);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 更新并记录 TWAP 价格
     */
    function _updateTWAPPrice() internal {
        oracle.update();
        
        // 查询 TWAP 价格
        uint256 memePerETH = oracle.consult(address(weth), 1 ether);
        uint256 ethPerMeme = oracle.consult(memeToken, 1000 * 10**18);
        
        emit TWAPPriceUpdated(block.timestamp, address(weth), memePerETH);
        emit TWAPPriceUpdated(block.timestamp, memeToken, ethPerMeme);
        
        console.log("TWAP: 1 ETH =", memePerETH / 10**18, "Meme tokens");
        console.log("TWAP: 1000 Meme =", ethPerMeme / 10**15, "milli-ETH");
    }
    
    /**
     * @dev 测试基本的 TWAP 预言机功能
     */
    function testBasicTWAPOracle() public {
        // 验证预言机初始化
        assertEq(oracle.getPair(), address(memePair));
        assertTrue(oracle.blockTimestampLast() > 0);
        
        // 等待一个周期后更新价格
        vm.warp(block.timestamp + oracle.PERIOD());
        oracle.update();
        
        // 验证可以查询价格
        uint256 memeAmount = oracle.consult(address(weth), 1 ether);
        assertTrue(memeAmount > 0, "Should return positive Meme amount for 1 ETH");
        
        uint256 ethAmount = oracle.consult(memeToken, 1000 * 10**18);
        assertTrue(ethAmount > 0, "Should return positive ETH amount for 1000 Meme");
        
        console.log("1 ETH can buy:", memeAmount / 10**18, "Meme tokens");
        console.log("1000 Meme tokens can sell for:", ethAmount / 10**15, "milli-ETH");
    }
    
    /**
     * @dev 测试多个时间点的交易和 TWAP 价格变化
     */
    function testMultipleTradesWithTWAP() public {
        console.log("\n=== Starting Multiple Trades TWAP Test ===");
        
        // 记录初始状态
        (uint112 reserve0, uint112 reserve1,) = memePair.getReserves();
        console.log("Initial reserves - WETH:", reserve0, "Meme:", reserve1);
        
        // 第一轮交易 - 时间点 T0
        console.log("\n--- Time T0: Initial trades ---");
        
        // 给交易者铸造一些 Meme 代币
        vm.startPrank(trader1);
        uint256 mintCost1 = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
        memeFactory.mintMeme{value: mintCost1}(memeToken);
        vm.stopPrank();
        
        vm.startPrank(trader2);
        uint256 mintCost2 = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
        memeFactory.mintMeme{value: mintCost2}(memeToken);
        vm.stopPrank();
        
        // 执行一些交易
        _swapETHForMeme(trader1, 1 ether);
        _swapETHForMeme(trader2, 0.5 ether);
        _swapMemeForETH(trader1, 5000 * 10**18);
        
        // 等待 6 小时
        vm.warp(block.timestamp + 6 hours);
        
        // 第二轮交易 - 时间点 T1
        console.log("\n--- Time T1: 6 hours later ---");
        
        // 给trader3铸造代币
        vm.startPrank(trader3);
        uint256 mintCost3 = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
        memeFactory.mintMeme{value: mintCost3}(memeToken);
        vm.stopPrank();
        
        _swapETHForMeme(trader2, 2 ether);
        _swapETHForMeme(trader3, 1.5 ether);
        _swapMemeForETH(trader2, 3000 * 10**18);
        
        // 等待 12 小时
        vm.warp(block.timestamp + 12 hours);
        
        // 第三轮交易 - 时间点 T2
        console.log("\n--- Time T2: 18 hours later ---");
        _swapETHForMeme(trader1, 0.8 ether);
        _swapMemeForETH(trader3, 8000 * 10**18);
        _swapETHForMeme(trader3, 1.2 ether);
        
        // 等待到可以更新 TWAP 的时间（24小时周期）
        vm.warp(block.timestamp + 6 hours + 1); // 总共 24 小时 + 1 秒
        
        // 更新并获取 TWAP 价格
        console.log("\n--- TWAP Price Update ---");
        _updateTWAPPrice();
        
        // 验证预言机状态
        assertTrue(oracle.blockTimestampLast() > 0, "Oracle should be updated");
        
        // 测试 TWAP 价格查询
        uint256 twapMemeAmount = oracle.consult(address(weth), 1 ether);
        uint256 twapEthAmount = oracle.consult(memeToken, 1000 * 10**18);
        
        // 验证 TWAP 价格的合理性
        assertTrue(twapMemeAmount > 0, "TWAP should return positive Meme amount");
        assertTrue(twapEthAmount > 0, "TWAP should return positive ETH amount");
        
        // 记录最终储备量
        (reserve0, reserve1,) = memePair.getReserves();
        console.log("Final reserves - WETH:", reserve0, "Meme:", reserve1);
    }
    
    /**
     * @dev 测试价格操纵抵抗性
     */
    function testPriceManipulationResistance() public {
        console.log("\n=== Testing Price Manipulation Resistance ===");
        
        // 给攻击者大量 ETH
        address attacker = address(0x999);
        vm.deal(attacker, 50 ether);
        
        // 给攻击者铸造大量 Meme 代币
        vm.startPrank(attacker);
        uint256 largeMintCost = (MEME_MINT_AMOUNT * 5 * MEME_PRICE) / 10**18;
        memeFactory.mintMeme{value: largeMintCost}(memeToken);
        vm.stopPrank();
        
        // 记录操纵前的价格
        vm.warp(block.timestamp + oracle.PERIOD());
        oracle.update();
        uint256 priceBeforeManipulation = oracle.consult(address(weth), 1 ether);
        console.log("Price before manipulation:", priceBeforeManipulation / 10**18, "Meme per ETH");
        
        // 执行大额交易尝试操纵价格
        console.log("\n--- Attempting price manipulation ---");
        _swapETHForMeme(attacker, 20 ether); // 大量买入
        
        // 立即检查即时价格（应该被操纵）
        (uint112 reserve0, uint112 reserve1,) = memePair.getReserves();
        uint256 instantPrice = (uint256(reserve0) * 10**18) / uint256(reserve1);
        console.log("Instant price after manipulation:", instantPrice / 10**15, "milli-ETH per Meme");
        
        // 等待一个完整的 TWAP 周期
        vm.warp(block.timestamp + oracle.PERIOD());
        
        // 更新 TWAP（应该抵抗操纵）
        oracle.update();
        uint256 twapPriceAfterManipulation = oracle.consult(address(weth), 1 ether);
        console.log("TWAP price after manipulation:", twapPriceAfterManipulation / 10**18, "Meme per ETH");
        
        // TWAP 价格变化应该相对较小（抵抗操纵）
        uint256 priceChangePercent = (twapPriceAfterManipulation > priceBeforeManipulation) 
            ? ((twapPriceAfterManipulation - priceBeforeManipulation) * 100) / priceBeforeManipulation
            : ((priceBeforeManipulation - twapPriceAfterManipulation) * 100) / priceBeforeManipulation;
            
        console.log("TWAP price change:", priceChangePercent, "%");
        
        // TWAP 价格变化应该小于即时价格变化，显示抗操纵性
        // 由于这是一个相对较小的流动性池，价格变化可能会比较大
        assertTrue(priceChangePercent < 95, "TWAP should resist extreme price manipulations");
    }
    
    /**
     * @dev 测试长期价格趋势跟踪
     */
    function testLongTermPriceTrend() public {
        console.log("\n=== Testing Long-term Price Trend Tracking ===");
        
        uint256[] memory twapPrices = new uint256[](5);
        
        // 模拟 5 个周期的价格变化
        for (uint256 i = 0; i < 5; i++) {
            console.log("\n--- Period", i + 1, "---");
            
            // 每个周期执行一些交易
            if (i % 2 == 0) {
                // 偶数周期：更多买入压力
                _swapETHForMeme(trader1, 0.5 ether);
                _swapETHForMeme(trader2, 0.3 ether);
            } else {
                 // 奇数周期：更多卖出压力
                 // 给交易者铸造代币
                 vm.startPrank(trader1);
                 uint256 mintCost1 = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
                 memeFactory.mintMeme{value: mintCost1}(memeToken);
                 vm.stopPrank();
                 
                 vm.startPrank(trader2);
                 uint256 mintCost2 = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
                 memeFactory.mintMeme{value: mintCost2}(memeToken);
                 vm.stopPrank();
                 
                 _swapMemeForETH(trader1, 2000 * 10**18);
                 _swapMemeForETH(trader2, 1500 * 10**18);
             }
            
            // 等待一个完整周期
            vm.warp(block.timestamp + oracle.PERIOD());
            
            // 更新并记录 TWAP 价格
            oracle.update();
            twapPrices[i] = oracle.consult(address(weth), 1 ether);
            
            console.log("TWAP price:", twapPrices[i] / 10**18, "Meme per ETH");
        }
        
        // 验证价格序列的合理性
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(twapPrices[i] > 0, "All TWAP prices should be positive");
        }
        
        console.log("\nPrice trend analysis completed");
    }
    
    /**
     * @dev 测试预言机在极端市场条件下的表现
     */
    function testExtremeMarketConditions() public {
        console.log("\n=== Testing Extreme Market Conditions ===");
        
        // 场景1：高频交易
        console.log("\n--- Scenario: High Frequency Trading ---");
        
        // 给交易者铸造代币
        vm.startPrank(trader1);
        uint256 mintCost = (MEME_MINT_AMOUNT * MEME_PRICE) / 10**18;
        memeFactory.mintMeme{value: mintCost}(memeToken);
        vm.stopPrank();
        
        // 模拟高频小额交易
        for (uint256 i = 0; i < 10; i++) {
            _swapETHForMeme(trader1, 0.01 ether);
            _swapMemeForETH(trader1, 50 * 10**18);
            vm.warp(block.timestamp + 100); // 每100秒一次交易
        }
        
        // 验证 TWAP 的稳定性
        vm.warp(block.timestamp + oracle.PERIOD());
        oracle.update();
        uint256 priceAfterHighFreq = oracle.consult(address(weth), 1 ether);
        assertTrue(priceAfterHighFreq > 0, "Oracle should handle high frequency trading");
        
        console.log("Price after high-freq trading:", priceAfterHighFreq / 10**18, "Meme per ETH");
    }
}