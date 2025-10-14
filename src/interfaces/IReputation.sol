// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReputation {
    function add(address user, uint256 amount) external;
    function get(address user) external view returns (uint256);
}
