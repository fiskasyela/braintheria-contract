// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {QnAWithBounty} from "../src/core/QnAWithBounty.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Owner can be the deployer EOA or a Safe later
        QnAWithBounty qna = new QnAWithBounty(vm.addr(pk));
        console2.log("QnAWithBounty:", address(qna));

        vm.stopBroadcast();
    }
}
