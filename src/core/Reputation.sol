// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Reputation
/// @notice Minimal reputation ledger; a designated registry can increment points.
contract Reputation {
    address public owner; // admin who can set registry
    address public registry; // QuestionRegistry allowed to add()

    mapping(address => uint256) private _rep;

    event ReputationIncreased(
        address indexed user,
        uint256 amount,
        uint256 newTotal
    );
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);
    event RegistrySet(address indexed registry);

    error NotOwner();
    error NotRegistry();
    error RegistryAlreadySet();

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRegistry() {
        if (msg.sender != registry) revert NotRegistry();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnerTransferred(msg.sender, newOwner);
    }

    /// @notice One-time set after deploying QuestionRegistry.
    function setRegistry(address _registry) external onlyOwner {
        if (registry != address(0)) revert RegistryAlreadySet();
        registry = _registry;
        emit RegistrySet(_registry);
    }

    function add(address user, uint256 amount) external onlyRegistry {
        uint256 after_ = _rep[user] + amount;
        _rep[user] = after_;
        emit ReputationIncreased(user, amount, after_);
    }

    function get(address user) external view returns (uint256) {
        return _rep[user];
    }
}
