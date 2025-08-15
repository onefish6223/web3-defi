// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/option/CallOption.sol";
import "../src/MockERC20.sol";

/**
 * @title DeployCallOption
 * @dev 部署看涨期权合约的脚本
 */
contract DeployCallOption is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署USDT代币（用于测试）
        MockERC20 usdtToken = new MockERC20("USDT", "USDT", 6);
        console.log("USDT Token deployed at:", address(usdtToken));
        
        // 期权参数
        string memory optionName = "ETH Call Option Dec 2024";
        string memory optionSymbol = "ETH-CALL-DEC24";
        uint256 strikePrice = 3000e6; // 3000 USDT per ETH (6 decimals)
        uint256 expirationDate = block.timestamp + 30 days; // 30天后到期
        uint256 underlyingPrice = 2500e6; // 当前ETH价格 2500 USDT (6 decimals)
        address underlyingAsset = address(0); // ETH
        
        // 部署期权合约
        CallOption callOption = new CallOption(
            optionName,
            optionSymbol,
            strikePrice,
            expirationDate,
            underlyingPrice,
            underlyingAsset,
            address(usdtToken)
        );
        
        console.log("CallOption deployed at:", address(callOption));
        console.log("Strike Price:", strikePrice / 1e6, "USDT per ETH");
        console.log("Expiration Date:", expirationDate);
        console.log("Underlying Price:", underlyingPrice / 1e6, "USDT per ETH");
        
        // 给部署者一些USDT用于测试
        usdtToken.mint(msg.sender, 1000000e6); // 1,000,000 USDT
        console.log("Minted 1,000,000 USDT to deployer:", msg.sender);
        
        vm.stopBroadcast();
        
        // 输出使用说明
        console.log("\n=== Usage Instructions ===");
        console.log("1. Issue options: callOption.issueOptions{value: ethAmount}()");
        console.log("2. Transfer options: callOption.transfer(userAddress, optionAmount)");
        console.log("3. Exercise options: callOption.exerciseOption(optionAmount)");
        console.log("4. Expire options: callOption.expireOptions()");
        console.log("\n=== Contract Addresses ===");
        console.log("USDT Token:", address(usdtToken));
        console.log("Call Option:", address(callOption));
    }
}