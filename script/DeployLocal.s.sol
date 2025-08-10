// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "../src/WETH.sol";

/**
 * @title DeployLocal
 * @dev 本地部署脚本，用于快速测试套利系统
 */
contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying on local network...");
        console.log("Deployer:", deployer);
        
        // 部署WETH
        WETH weth = new WETH();
        console.log("WETH:", address(weth));
        
        // 部署代币
        MyToken tokenA = new MyToken("Token A", "TKA", 18, 1000000, deployer);
        MyToken tokenB = new MyToken("Token B", "TKB", 18, 1000000, deployer);
        
        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        
        vm.stopBroadcast();
    }
}