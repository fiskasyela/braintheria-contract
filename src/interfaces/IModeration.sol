// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IModeration {
    function isFlagged(bytes32 contentKey) external view returns (bool);
}
