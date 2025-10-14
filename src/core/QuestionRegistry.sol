// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IReputation} from "../interfaces/IReputation.sol";
import {IModeration} from "../interfaces/IModeration.sol";

/// @title QuestionRegistry
/// @notice Post questions with ETH/ERC20 bounties, post answers, accept winner, or refund on expiry.
/// @dev v1.1 adds: fees/treasury, pausability, optional moderation hook.
contract QuestionRegistry {
    // ============ Admin / Config ============
    address public owner;
    IReputation public reputation; // reputation contract
    IModeration public moderation; // optional; can be address(0)

    bool public paused; // circuit breaker

    uint16 public feeBps; // protocol fee in basis points (1% = 100)
    address public treasury; // fee receiver

    // ============ Types ============
    struct Question {
        address asker;
        bytes32 cid; // off-chain pointer (digest/keccak of full CID)
        address bountyToken; // address(0) = ETH
        uint256 bountyAmount; // escrowed amount
        uint64 deadline; // unix seconds
        uint8 status; // 0=Open, 1=Accepted, 2=Refunded
        uint32 answersCount; // number of answers
    }

    struct Answer {
        address author;
        bytes32 cid; // off-chain pointer
        bool rewarded; // true if winner
    }

    // ============ Storage ============
    uint256 public questionCount;
    mapping(uint256 => Question) public questions;
    mapping(uint256 => Answer[]) private _answers;

    // ============ Constants & Guards ============
    bool private _entered; // nonReentrant
    uint256 public constant REP_ON_ACCEPT = 10;

    // ============ Events/Errors ============
    event QuestionCreated(
        uint256 indexed id,
        address indexed asker,
        bytes32 cid,
        address bountyToken,
        uint256 bountyAmount,
        uint64 deadline
    );
    event AnswerPosted(
        uint256 indexed id,
        uint256 indexed answerId,
        address indexed author,
        bytes32 cid
    );
    event AnswerAccepted(
        uint256 indexed id,
        uint256 indexed answerId,
        address indexed author,
        address bountyToken,
        uint256 netToWinner,
        uint256 fee
    );
    event BountyRefunded(
        uint256 indexed id,
        address indexed to,
        address bountyToken,
        uint256 amount
    );

    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnerTransferred(address indexed oldOwner, address indexed newOwner);
    event FeeUpdated(uint16 bps);
    event TreasuryUpdated(address indexed treasury);
    event ReputationUpdated(address indexed reputation);
    event ModerationUpdated(address indexed moderation);

    error NotOwner();
    error PausedErr();
}
