// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract QnAAdmin is Pausable, Ownable {
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    constructor(address _owner) Ownable(_owner) {}

    function pause() public onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    function unpause() public onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }
}
