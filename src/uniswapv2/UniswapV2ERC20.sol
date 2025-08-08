// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2ERC20.sol";
import "./libraries/SafeMath.sol";

/**
 * @title UniswapV2ERC20
 * @dev UniswapV2 ERC20代币实现
 * 实现了标准ERC20功能，并增加了EIP-2612 permit功能
 * 用作流动性代币（LP Token）的基础合约
 */
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint256;

    // ERC20基本信息
    string public constant name = "Uniswap V2";
    string public constant symbol = "UNI-V2";
    uint8 public constant decimals = 18;
    
    // 代币状态变量
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // EIP-2612 permit相关
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    /**
     * @dev 构造函数
     * 初始化EIP-712域分隔符，用于permit功能
     */
    constructor() {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @dev 内部铸币函数
     * @param to 接收代币的地址
     * @param value 铸造的代币数量
     */
    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev 内部销毁函数
     * @param from 销毁代币的地址
     * @param value 销毁的代币数量
     */
    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev 内部授权函数
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权数量
     */
    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev 内部转账函数
     * @param from 发送方
     * @param to 接收方
     * @param value 转账数量
     */
    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev ERC20标准：授权
     * @param spender 被授权者地址
     * @param value 授权数量
     * @return 是否成功
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev ERC20标准：转账
     * @param to 接收方地址
     * @param value 转账数量
     * @return 是否成功
     */
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev ERC20标准：授权转账
     * @param from 发送方地址
     * @param to 接收方地址
     * @param value 转账数量
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev EIP-2612 permit函数
     * 允许通过签名进行授权，避免需要发送交易
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权数量
     * @param deadline 签名有效期
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, "UniswapV2: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "UniswapV2: INVALID_SIGNATURE");
        _approve(owner, spender, value);
    }
}