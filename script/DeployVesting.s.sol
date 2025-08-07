// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
import "../src/MockERC20.sol";

contract DeployVesting is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // wake-disable-next-line
        address deployer = vm.addr(deployerPrivateKey);
        address beneficiary = vm.envAddress("BENEFICIARY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockERC20 token with 10 million supply
        MockERC20 token = new MockERC20(
            "Test Token",
            "TEST",
            10_000_000 * 10**18 // 10 million tokens with 18 decimals
        );

        console.log("MockERC20 deployed at:", address(token));

        // Deploy TokenVesting contract
        // 1,000,000 tokens to be vested
        uint256 vestingAmount = 1_000_000 * 10**18;
        TokenVesting vesting = new TokenVesting(
            beneficiary,
            address(token),
            vestingAmount,
            true // revocable
        );

        console.log("TokenVesting deployed at:", address(vesting));
        console.log("Beneficiary:", beneficiary);
        console.log("Vesting amount:", vestingAmount);

        // Transfer 1 million tokens to the vesting contract
        token.transfer(address(vesting), vestingAmount);
        
        console.log("Transferred", vestingAmount, "tokens to vesting contract");
        console.log("Vesting contract balance:", token.balanceOf(address(vesting)));

        vm.stopBroadcast();
    }
}