// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
/**
 * @title KK Token 
 */
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}