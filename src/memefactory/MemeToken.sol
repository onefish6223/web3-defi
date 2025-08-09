// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title MemeToken
 * @dev ERC20代币模板合约，用于通过最小代理模式创建Meme代币
 */
contract MemeToken is ERC20, Ownable, Initializable {
    uint256 public totalSupplyLimit;  // 总发行量限制
    uint256 public perMint;           // 每次铸造数量
    uint256 public price;             // 每个代币的价格（wei）
    address public creator;           // 代币创建者
    address public factory;           // 工厂合约地址
    
    uint256 public totalMinted;       // 已铸造总量
    
    event TokenMinted(address indexed to, uint256 amount, uint256 payment);
    
    constructor() ERC20("MemeTemplate", "MEME") Ownable(msg.sender) {
        // 在模板合约中禁用初始化
        _disableInitializers();
    }
    
    /**
     * @dev 初始化代币参数（用于代理合约）
     * @param _symbol 代币符号
     * @param _totalSupply 总发行量
     * @param _perMint 每次铸造数量
     * @param _price 每个代币价格
     * @param _creator 代币创建者
     * @param _factory 工厂合约地址
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator,
        address _factory
    ) external {
        // 手动检查初始化状态，避免initializer修饰符的潜在重入风险
        require(factory == address(0), "Already initialized");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint cannot exceed total supply");
        require(_creator != address(0), "Creator cannot be zero address");
        require(_factory != address(0), "Factory cannot be zero address");
        
        // 由于使用标准ERC20和Ownable（非升级版本），需要手动设置存储
        // 直接设置ERC20的name和symbol存储槽
        // 对于字符串，需要正确处理长度和数据
        assembly {
            let nameLen := mload(_name)
            let symbolLen := mload(_symbol)
            
            // 如果字符串长度小于32字节，使用短字符串格式
            if lt(nameLen, 32) {
                // 短字符串：长度*2存储在最低位，数据存储在高位
                let nameData := mload(add(_name, 0x20))
                sstore(3, or(nameData, mul(nameLen, 2)))
            }
            
            if lt(symbolLen, 32) {
                let symbolData := mload(add(_symbol, 0x20))
                sstore(4, or(symbolData, mul(symbolLen, 2)))
            }
        }
        // 设置参数
        totalSupplyLimit = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;
        factory = _factory;
        totalMinted = 0;
        
        // 直接设置所有者，避免潜在的重入风险
        // 使用内联汇编直接设置owner存储槽
        assembly {
            sstore(0, _creator)
        }
    }
    
    /**
     * @dev 铸造代币（只能由工厂合约调用）
     * @param to 接收者地址
     * @return success 是否成功
     */
    function mint(address to) external returns (bool success) {
        require(msg.sender == factory, "Only factory can mint");
        require(to != address(0), "Cannot mint to zero address");
        require(totalMinted + perMint <= totalSupplyLimit, "Exceeds total supply");
        
        _mint(to, perMint);
        totalMinted += perMint;
        
        emit TokenMinted(to, perMint, price);
        return true;
    }
    
    /**
     * @dev 获取剩余可铸造数量
     */
    function remainingSupply() external view returns (uint256) {
        return totalSupplyLimit - totalMinted;
    }
    
    /**
     * @dev 检查是否还可以铸造
     */
    function canMint() external view returns (bool) {
        return totalMinted + perMint <= totalSupplyLimit;
    }
}