// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Moderation
/// @notice Simple role-gated flag list for content keys; used by registry to block payouts.
contract Moderation {
    address public owner;
    mapping(address => bool) public isModerator;

    // contentKey is a bytes32 that identifies a question or answer deterministically.
    mapping(bytes32 => bool) private _flagged;

    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);
    event ModeratorSet(address indexed mod, bool enabled);
    event ContentFlagged(
        bytes32 indexed key,
        address indexed by,
        string reason
    );
    event ContentUnflagged(
        bytes32 indexed key,
        address indexed by,
        string reason
    );

    error NotOwner();
    error NotOwnerOrModerator();

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyOwnerOrMod() {
        if (msg.sender != owner && !isModerator[msg.sender])
            revert NotOwnerOrModerator();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnerTransferred(msg.sender, newOwner);
    }

    function setModerator(address mod, bool enabled) external onlyOwner {
        isModerator[mod] = enabled;
        emit ModeratorSet(mod, enabled);
    }

    function flag(
        bytes32 contentKey,
        string calldata reason
    ) external onlyOwnerOrMod {
        _flagged[contentKey] = true;
        emit ContentFlagged(contentKey, msg.sender, reason);
    }

    function unflag(
        bytes32 contentKey,
        string calldata reason
    ) external onlyOwnerOrMod {
        _flagged[contentKey] = false;
        emit ContentUnflagged(contentKey, msg.sender, reason);
    }

    function isFlagged(bytes32 contentKey) external view returns (bool) {
        return _flagged[contentKey];
    }
}
