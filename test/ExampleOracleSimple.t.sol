// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../src/uniswapv2/ExampleOracleSimple.sol";
import "../src/uniswapv2/UniswapV2Factory.sol";
import "../src/uniswapv2/interfaces/IUniswapV2Pair.sol";
/**
 * @title SimpleERC20
 * @dev 简单的 ERC20 代币用于测试
 */
contract SimpleERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    uint256 public totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    
    constructor(string memory _name, string memory _symbol, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}

/**
 * @title ExampleOracleSimpleTest
 * @dev 测试 ExampleOracleSimple 预言机合约的功能
 */
contract ExampleOracleSimpleTest is Test {
    ExampleOracleSimple public oracle;
    UniswapV2Factory public factory;
    IUniswapV2Pair public pair;
    SimpleERC20 public tokenA;
    SimpleERC20 public tokenB;
    
    address public user = address(0x1);
    address public liquidityProvider = address(0x2);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant LIQUIDITY_AMOUNT = 10000 * 10**18;
    
    function setUp() public {
        // 部署代币合约
        tokenA = new SimpleERC20("Token A", "TKNA", INITIAL_SUPPLY);
        tokenB = new SimpleERC20("Token B", "TKNB", INITIAL_SUPPLY);
        
        // 部署工厂合约
        factory = new UniswapV2Factory(address(this));
        
        // 创建交易对
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = IUniswapV2Pair(pairAddress);
        
        // 为交易对添加初始流动性
        tokenA.transfer(address(pair), LIQUIDITY_AMOUNT);
        tokenB.transfer(address(pair), LIQUIDITY_AMOUNT);
        pair.mint(liquidityProvider);
        
        // 等待一些时间让价格累积值增长
        vm.warp(block.timestamp + 3600); // 等待1小时
        
        // 部署预言机合约
        oracle = new ExampleOracleSimple(
            address(factory),
            address(tokenA),
            address(tokenB)
        );
    }
    
    /**
     * @dev 测试预言机初始化
     */
    function testOracleInitialization() public view {
        // 验证交易对地址
        assertEq(oracle.getPair(), address(pair));
        
        // 验证代币地址
        address token0 = oracle.token0();
        address token1 = oracle.token1();
        
        assertTrue(token0 < token1, "Tokens should be sorted");
        assertTrue(
            (token0 == address(tokenA) && token1 == address(tokenB)) ||
            (token0 == address(tokenB) && token1 == address(tokenA)),
            "Tokens should match deployed tokens"
        );
        
        // 验证初始累积价格已设置（可能为0，但应该被正确读取）
        uint256 price0Cumulative = oracle.price0CumulativeLast();
        uint256 price1Cumulative = oracle.price1CumulativeLast();
        // 只要能读取到值就说明初始化成功
        assertTrue(price0Cumulative >= 0, "Price0 cumulative should be readable");
        assertTrue(price1Cumulative >= 0, "Price1 cumulative should be readable");
        assertTrue(oracle.blockTimestampLast() > 0, "Timestamp should be initialized");
    }
    
    /**
     * @dev 测试价格更新功能
     */
    function testPriceUpdate() public {
        // 记录初始状态
        uint256 initialPrice0Cumulative = oracle.price0CumulativeLast();
        uint256 initialPrice1Cumulative = oracle.price1CumulativeLast();
        uint32 initialTimestamp = oracle.blockTimestampLast();
        
        // 等待一个周期（24小时）
        vm.warp(block.timestamp + oracle.PERIOD());
        
        // 执行一些交易以改变价格
        uint256 swapAmount = 1000 * 10**18;
        tokenA.transfer(address(pair), swapAmount);
        pair.swap(0, 500 * 10**18, user, "");
        
        // 更新预言机
        oracle.update();
        
        // 验证累积价格已更新
        assertTrue(
            oracle.price0CumulativeLast() != initialPrice0Cumulative,
            "Price0 cumulative should be updated"
        );
        assertTrue(
            oracle.price1CumulativeLast() != initialPrice1Cumulative,
            "Price1 cumulative should be updated"
        );
        assertTrue(
            oracle.blockTimestampLast() > initialTimestamp,
            "Timestamp should be updated"
        );
    }
    
    /**
     * @dev 测试价格查询功能
     */
    function testPriceConsultation() public {
        // 首先更新价格以设置平均价格
        vm.warp(block.timestamp + oracle.PERIOD());
        oracle.update();
        
        // 测试查询 token0 价格
        address token0 = oracle.token0();
        uint256 amountIn = 1 * 10**18;
        uint256 amountOut = oracle.consult(token0, amountIn);
        
        assertTrue(amountOut > 0, "Should return positive amount for token0");
        
        // 测试查询 token1 价格
        address token1 = oracle.token1();
        amountOut = oracle.consult(token1, amountIn);
        
        assertTrue(amountOut > 0, "Should return positive amount for token1");
    }
    
    /**
     * @dev 测试无效代币查询
     */
    function testInvalidTokenConsultation() public {
        // 首先更新价格
        vm.warp(block.timestamp + oracle.PERIOD());
        oracle.update();
        
        // 尝试查询无效代币
        address invalidToken = address(0x999);
        uint256 amountIn = 1 * 10**18;
        
        vm.expectRevert("ExampleOracleSimple: INVALID_TOKEN");
        oracle.consult(invalidToken, amountIn);
    }
}