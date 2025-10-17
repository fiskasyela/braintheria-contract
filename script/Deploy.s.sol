// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/core/QnAWithBounty.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy main contract
        QnAWithBounty qna = new QnAWithBounty(deployer);

        vm.stopBroadcast();

        // Log deployed address
        console.log("Deployer address:", deployer);
        console.log("QnAWithBounty deployed at:", address(qna));
    }
}
