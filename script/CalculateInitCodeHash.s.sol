// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/uniswapv2/UniswapV2Pair.sol";

contract CalculateInitCodeHash is Script {
    // wake-disable-next-line
    function run() public {
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 hash = keccak256(bytecode);
        console.log("UniswapV2Pair init code hash:");
        console.logBytes32(hash);
    }
}