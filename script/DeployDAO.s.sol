// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/dao/VotingToken.sol";
import "../src/dao/Bank.sol";
import "../src/dao/Gov.sol";

contract DeployDAO is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署投票代币
        VotingToken token = new VotingToken(
            "DAO Governance Token",
            "DAOGOV",
            1000000e18 // 100万代币
        );
        
        console.log("VotingToken deployed at:", address(token));

        // 部署银行合约
        Bank bank = new Bank();
        console.log("Bank deployed at:", address(bank));

        // 部署治理合约
        Gov gov = new Gov(address(token), address(bank));
        console.log("Gov deployed at:", address(gov));

        // 将银行的所有权转移给治理合约
        bank.transferOwnership(address(gov));
        console.log("Bank ownership transferred to Gov contract");

        // 输出部署信息
        console.log("\n=== DAO Deployment Summary ===");
        console.log("VotingToken:", address(token));
        console.log("Bank:", address(bank));
        console.log("Gov:", address(gov));
        console.log("\nInitial token supply:", token.totalSupply());
        console.log("Proposal threshold:", gov.proposalThreshold());
        console.log("Voting delay:", gov.votingDelay(), "blocks");
        console.log("Voting period:", gov.votingPeriod(), "blocks");
        console.log("Quorum numerator:", gov.quorumNumerator(), "%");

        vm.stopBroadcast();
    }
}