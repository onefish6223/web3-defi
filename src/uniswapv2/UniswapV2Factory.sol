// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Factory.sol";
import "./UniswapV2Pair.sol";

/**
 * @title UniswapV2Factory
 * @dev UniswapV2工厂合约
 * 负责创建和管理所有的交易对合约
 */
contract UniswapV2Factory is IUniswapV2Factory {
    // 协议手续费接收地址
    address public feeTo;
    // 有权设置协议手续费接收地址的管理员地址
    address public feeToSetter;

    // 存储所有交易对：token地址 => token地址 => 交易对地址
    mapping(address => mapping(address => address)) public getPair;
    // 存储所有交易对的数组
    address[] public allPairs;

    /**
     * @dev 构造函数
     * @param _feeToSetter 管理员地址
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @dev 获取所有交易对的总数量
     * @return 交易对总数量
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @dev 创建新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 新创建的交易对合约地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");
        
        // 按字典序排序代币地址
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "UniswapV2: PAIR_EXISTS"); // 单次检查就足够了
        
        // 获取交易对合约的字节码
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // 计算salt值（用于CREATE2）
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        // 使用CREATE2创建交易对合约
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // 初始化交易对
        // wake-disable-next-line reentrancy
        UniswapV2Pair(pair).initialize(token0, token1);
        
        // 存储交易对映射（双向存储）
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 填充反向映射
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 设置协议手续费接收地址（只有管理员可以调用）
     * @param _feeTo 新的协议手续费接收地址
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    /**
     * @dev 设置新的管理员地址（只有当前管理员可以调用）
     * @param _feeToSetter 新的管理员地址
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}