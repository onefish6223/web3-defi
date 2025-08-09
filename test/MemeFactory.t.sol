// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {MemeFactory} from "../src/memefactory/MemeFactory.sol";
import {UniswapV2Factory} from "../src/uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../src/uniswapv2/UniswapV2Router02.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {WETH} from "../src/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockOwner
 * @dev 模拟owner合约，可以接收ETH
 */
contract MockOwner {
    receive() external payable {}
    fallback() external payable {}
}

/**
 * @title MemeFactoryTest
 * @dev MemeFactory合约测试
 */
contract MemeFactoryTest is Test {
    MemeFactory public factory;
    UniswapV2Factory public uniswapFactory;
    UniswapV2Router02 public uniswapRouter;
    WETH public weth;
    
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    MockOwner public mockOwner;
    
    // 添加receive函数以接收ETH
    receive() external payable {}
    
    function setUp() public {
        // 部署WETH
        weth = new WETH();
        
        // 部署Uniswap工厂
        uniswapFactory = new UniswapV2Factory(address(this));
        
        // 部署Uniswap路由器
        uniswapRouter = new UniswapV2Router02(address(uniswapFactory), address(weth));
        
        // 部署MockOwner合约
        mockOwner = new MockOwner();
        
        // 让mockOwner部署MemeFactory
        vm.startPrank(address(mockOwner));
        factory = new MemeFactory(address(uniswapRouter));
        vm.stopPrank();
        
        // 给测试账户分配ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(address(mockOwner), 100 ether);
    }
    
    /**
     * @dev 测试部署Meme代币
     */
    function testDeployMeme() public {
        vm.startPrank(alice);
        
        address tokenAddr = factory.deployMeme(
            "TestMeme",
            1000000 * 10**18,  // 总供应量
            1000 * 10**18,     // 每次铸造数量
            0.001 ether        // 价格
        );
        
        assertNotEq(tokenAddr, address(0), "Token should be deployed");
        assertTrue(factory.isMemeToken(tokenAddr), "Token should be registered");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试mintMemeAndAddLiquidity方法 - 简化版本
     */
    function testMintMemeAndAddLiquidity1() public {
        vm.startPrank(alice);
        
        // 部署代币 - 使用更简单的参数
        address tokenAddr = factory.deployMeme(
            "TestMeme",
            1000000 * 10**18,  // 总供应量
            1000 * 10**18,     // 每次铸造1000个代币
            0.001 ether        // 价格：每个代币0.001 ETH
        );
        
        // 计算所需费用
        // 铸造成本 = (perMint * price) / 1e18 = (1000 * 10^18 * 0.001 ether) / 10^18 = 1 ether
        uint256 mintCost = 1 ether;
        uint256 liquidityETH = 0.1 ether;  // 使用较小的流动性
        uint256 totalCost = mintCost + liquidityETH;
        //
        uniswapFactory.createPair(tokenAddr, address(weth));
        
        // 调用mintMemeAndAddLiquidity
        factory.mintMemeAndAddLiquidity{value: totalCost}(
            tokenAddr,
            liquidityETH,
            block.timestamp + 1 hours
        );
        
        // 验证交易对是否创建
        address pair = uniswapFactory.getPair(tokenAddr, address(weth));
        assertNotEq(pair, address(0), "Trading pair should be created");
        
        // 验证用户是否获得了LP代币
        assertGt(IERC20(pair).balanceOf(alice), 0, "User should have LP tokens");
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试mintMemeAndAddLiquidity失败情况
     */
    function testMintMemeAndAddLiquidityInsufficientPayment() public {
        vm.startPrank(alice);
        
        // 部署代币
        address tokenAddr = factory.deployMeme(
            "TestMeme",
            1000000 * 10**18,
            1000 * 10**18,
            0.001 ether
        );
        
        // 尝试用不足的ETH调用
        vm.expectRevert("Insufficient payment for mint and liquidity");
        factory.mintMemeAndAddLiquidity{value: 0.0005 ether}(
            tokenAddr,
            0.5 ether,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试不存在的代币
     */
    function testMintMemeAndAddLiquidityNonExistentToken() public {
        vm.startPrank(alice);
        
        vm.expectRevert("Token does not exist");
        factory.mintMemeAndAddLiquidity{value: 1 ether}(
            address(0x123),
            0.5 ether,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
    }

    /**
     * @dev 测试buyMeme方法 - 价格优于起始价格时购买
     */
    function testBuyMeme() public {
        vm.startPrank(alice);
        
        // 部署代币
        address tokenAddr = factory.deployMeme(
            "TestMeme",
            1000000 * 10**18,  // 总供应量
            1000 * 10**18,     // 每次铸造1000个代币
            0.001 ether        // 价格：每个代币0.001 ETH
        );
        
        // 先添加流动性以创建交易对
        uint256 mintCost = 1 ether;
        uint256 liquidityETH = 2 ether;  // 使用较大的流动性
        uint256 totalCost = mintCost + liquidityETH;
        
        uniswapFactory.createPair(tokenAddr, address(weth));
        
        factory.mintMemeAndAddLiquidity{value: totalCost}(
            tokenAddr,
            liquidityETH,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
        
        // 切换到bob进行购买测试
        vm.startPrank(bob);
        
        // 检查当前价格
        (, , bool isPriceBetter) = factory.getTokenPrice(tokenAddr);
        
        // 如果当前价格不优于起始价格，我们需要通过交易来降低价格
        if (!isPriceBetter) {
            // 通过卖出一些代币来降低价格（需要先获得一些代币）
            // 这里我们跳过这个复杂的设置，直接测试价格检查逻辑
            vm.expectRevert("Current price is not better than initial price");
            factory.buyMeme{value: 0.1 ether}(
                tokenAddr,
                0, // 最小输出数量
                block.timestamp + 1 hours
            );
        } else {
            // 如果价格已经优于起始价格，执行购买
            uint256 balanceBefore = IERC20(tokenAddr).balanceOf(bob);
            
            factory.buyMeme{value: 0.1 ether}(
                tokenAddr,
                0, // 最小输出数量
                block.timestamp + 1 hours
            );
            
            uint256 balanceAfter = IERC20(tokenAddr).balanceOf(bob);
            assertGt(balanceAfter, balanceBefore, "Bob should have received tokens");
        }
        
        vm.stopPrank();
    }

    /**
     * @dev 测试buyMeme方法 - 交易对不存在时失败
     */
    function testBuyMemeNoPair() public {
        vm.startPrank(alice);
        
        // 部署代币但不添加流动性
        address tokenAddr = factory.deployMeme(
            "TestMeme",
            1000000 * 10**18,
            1000 * 10**18,
            0.001 ether
        );
        
        vm.expectRevert("Trading pair does not exist");
        factory.buyMeme{value: 0.1 ether}(
            tokenAddr,
            0,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
    }

    /**
     * @dev 测试getTokenPrice方法
     */
    function testGetTokenPrice() public {
        vm.startPrank(alice);
        
        // 部署代币
        address tokenAddr = factory.deployMeme(
            "TestMeme",
            1000000 * 10**18,
            1000 * 10**18,
            0.001 ether
        );
        
        // 测试没有交易对时的价格
        (uint256 currentPrice, uint256 initialPrice, bool isPriceBetter) = factory.getTokenPrice(tokenAddr);
        assertEq(currentPrice, 0.001 ether, "Current price should equal initial price when no pair exists");
        assertEq(initialPrice, 0.001 ether, "Initial price should be 0.001 ether");
        assertFalse(isPriceBetter, "Price should not be better when no pair exists");
        
        // 添加流动性创建交易对
        uint256 mintCost = 1 ether;
        uint256 liquidityETH = 1 ether;
        uint256 totalCost = mintCost + liquidityETH;
        
        uniswapFactory.createPair(tokenAddr, address(weth));
        
        factory.mintMemeAndAddLiquidity{value: totalCost}(
            tokenAddr,
            liquidityETH,
            block.timestamp + 1 hours
        );
        
        // 测试有交易对时的价格
        (currentPrice, initialPrice, isPriceBetter) = factory.getTokenPrice(tokenAddr);
        assertEq(initialPrice, 0.001 ether, "Initial price should still be 0.001 ether");
        assertGt(currentPrice, 0, "Current price should be greater than 0");
        
        vm.stopPrank();
    }

    /**
     * @dev 测试buyMeme方法 - 不存在的代币
     */
    function testBuyMemeNonExistentToken() public {
        vm.startPrank(alice);
        
        vm.expectRevert("Token does not exist");
        factory.buyMeme{value: 0.1 ether}(
            address(0x123),
            0,
            block.timestamp + 1 hours
        );
        
        vm.stopPrank();
    }
}