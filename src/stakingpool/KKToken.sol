// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IToken.sol";

/**
 * @title KK Token
 * @dev KK Token 合约，用于质押奖励
 */
contract KKToken is ERC20, Ownable, IToken {
    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {}

    /**
     * @dev 铸造代币（仅所有者）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external override onlyOwner {
        _mint(to, amount);
    }
}