// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title QnAWithBounty
 * @notice Brainly-like Q&A with optional bounty escrow. Asker can accept one best answer.
 *         Supports native token (address(0)) or arbitrary ERC20 (per-question).
 */
contract QnAWithBounty is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    enum QuestionStatus {
        Open,
        Resolved,
        Cancelled,
        Expired
    }
    enum AnswerStatus {
        Posted,
        Accepted,
        Rejected
    }

    struct Question {
        address asker;
        address token; // address(0) = native
        uint256 bounty; // escrowed amount
        uint40 createdAt;
        uint40 deadline; // after this, asker can refund if still Open
        QuestionStatus status;
        uint256 acceptedAnswerId; // 0 if none; answers are 1-indexed
        bool refunded;
        string uri; // IPFS/HTTP/CID pointer to content
        uint256 answersCount; // incremental counter (1..n)
    }

    struct Answer {
        address answerer;
        uint40 createdAt;
        AnswerStatus status;
        string uri; // IPFS/HTTP/CID pointer to content
    }

    // questionId => Question
    mapping(uint256 => Question) public questions;
    // questionId => answerId (1..answersCount) => Answer
    mapping(uint256 => mapping(uint256 => Answer)) public answers;

    // Simple reputation counters
    mapping(address => uint256) public answersAccepted;
    mapping(address => uint256) public questionsAsked;
    mapping(address => uint256) public answersPosted;

    uint256 public questionCounter;
    uint256 public constant MIN_DEADLINE_DELAY = 1 hours;

    // --- Events ---
    event QuestionAsked(
        uint256 indexed questionId,
        address indexed asker,
        address indexed token,
        uint256 bounty,
        uint40 deadline,
        string uri
    );
    event AnswerPosted(
        uint256 indexed questionId,
        uint256 indexed answerId,
        address indexed answerer,
        string uri
    );
    event AnswerAccepted(
        uint256 indexed questionId,
        uint256 indexed answerId,
        address indexed asker,
        address winner
    );
    event BountyPaid(
        uint256 indexed questionId,
        address indexed to,
        uint256 amount,
        address token
    );
    event BountyRefunded(
        uint256 indexed questionId,
        address indexed to,
        uint256 amount,
        address token
    );
    event BountyAdded(
        uint256 indexed questionId,
        uint256 amount,
        address token
    );
    event QuestionCancelled(uint256 indexed questionId, address indexed by);

    // --- Modifiers ---
    modifier onlyAsker(uint256 questionId) {
        require(msg.sender == questions[questionId].asker, "Not asker");
        _;
    }

    // --- Admin/Pause ---
    constructor(address _owner) Ownable(_owner) {}

    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }

    // --- Core flows ---

    /**
     * @dev Ask a question with optional bounty.
     * @param token address(0) for native; otherwise ERC20 address
     * @param bounty amount to escrow now (must be >0 if you want a bounty; 0 allowed)
     * @param deadline timestamp in the future (>= now + MIN_DEADLINE_DELAY)
     * @param uri content pointer (e.g., IPFS CID)
     */
    function askQuestion(
        address token,
        uint256 bounty,
        uint40 deadline,
        string calldata uri
    ) external payable whenNotPaused nonReentrant returns (uint256 questionId) {
        require(
            deadline >= block.timestamp + MIN_DEADLINE_DELAY,
            "Deadline too soon"
        );

        questionId = ++questionCounter;

        // Handle escrow
        if (token == address(0)) {
            // native
            require(msg.value == bounty, "Bad msg.value");
        } else {
            require(msg.value == 0, "No native with ERC20");
            if (bounty > 0)
                IERC20(token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    bounty
                );
        }

        Question storage q = questions[questionId];
        q.asker = msg.sender;
        q.token = token;
        q.bounty = bounty;
        q.createdAt = uint40(block.timestamp);
        q.deadline = deadline;
        q.status = QuestionStatus.Open;
        q.uri = uri;

        questionsAsked[msg.sender] += 1;

        emit QuestionAsked(
            questionId,
            msg.sender,
            token,
            bounty,
            q.deadline,
            uri
        );
    }

    /**
     * @dev Post an answer to an open question.
     */
    function answerQuestion(
        uint256 questionId,
        string calldata uri
    ) external whenNotPaused {
        Question storage q = questions[questionId];
        require(q.asker != address(0), "Q not found");
        require(q.status == QuestionStatus.Open, "Not open");

        uint256 newId = ++q.answersCount; // 1-indexed
        answers[questionId][newId] = Answer({
            answerer: msg.sender,
            createdAt: uint40(block.timestamp),
            status: AnswerStatus.Posted,
            uri: uri
        });

        answersPosted[msg.sender] += 1;
        emit AnswerPosted(questionId, newId, msg.sender, uri);
    }

    /**
     * @dev Asker accepts the best answer. Pays out bounty to winner.
     */
    function acceptAnswer(
        uint256 questionId,
        uint256 answerId
    ) external onlyAsker(questionId) nonReentrant {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(answerId > 0 && answerId <= q.answersCount, "Bad answerId");
        Answer storage a = answers[questionId][answerId];
        require(a.status == AnswerStatus.Posted, "Already handled");

        // Effects
        a.status = AnswerStatus.Accepted;
        q.status = QuestionStatus.Resolved;
        q.acceptedAnswerId = answerId;

        address winner = a.answerer;
        uint256 amount = q.bounty;
        address token = q.token;

        // Interactions
        if (amount > 0) {
            q.bounty = 0; // **checks-effects-interactions**
            if (token == address(0)) {
                (bool ok, ) = winner.call{value: amount}("");
                require(ok, "Native payout failed");
            } else {
                IERC20(token).safeTransfer(winner, amount);
            }
            emit BountyPaid(questionId, winner, amount, token);
        }

        answersAccepted[winner] += 1;
        emit AnswerAccepted(questionId, answerId, q.asker, winner);
    }

    /**
     * @dev Add more bounty while question is still open.
     * @notice For ERC20, caller must approve first.
     */
    function addBounty(
        uint256 questionId,
        uint256 amount
    ) external payable nonReentrant {
        require(amount > 0, "No amount");
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        address token = q.token;

        if (token == address(0)) {
            require(msg.value == amount, "Bad msg.value");
        } else {
            require(msg.value == 0, "No native with ERC20");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        q.bounty += amount;
        emit BountyAdded(questionId, amount, token);
    }

    /**
     * @dev After deadline, if still Open and not accepted, asker can refund bounty.
     */
    function refundExpired(
        uint256 questionId
    ) external onlyAsker(questionId) nonReentrant {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(block.timestamp >= q.deadline, "Not expired");
        require(!q.refunded, "Already refunded");

        q.status = QuestionStatus.Expired;
        q.refunded = true;

        uint256 amount = q.bounty;
        q.bounty = 0;
        address token = q.token;

        if (amount > 0) {
            if (token == address(0)) {
                (bool ok, ) = q.asker.call{value: amount}("");
                require(ok, "Native refund failed");
            } else {
                IERC20(token).safeTransfer(q.asker, amount);
            }
            emit BountyRefunded(questionId, q.asker, amount, token);
        }
    }

    /**
     * @dev Let asker cancel before any answer exists. Refund full bounty.
     */
    function cancelQuestion(
        uint256 questionId
    ) external onlyAsker(questionId) nonReentrant {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(q.answersCount == 0, "Already answered");

        q.status = QuestionStatus.Cancelled;

        uint256 amount = q.bounty;
        q.bounty = 0;
        address token = q.token;

        if (amount > 0) {
            if (token == address(0)) {
                (bool ok, ) = q.asker.call{value: amount}("");
                require(ok, "Native refund failed");
            } else {
                IERC20(token).safeTransfer(q.asker, amount);
            }
            emit BountyRefunded(questionId, q.asker, amount, token);
        }

        emit QuestionCancelled(questionId, msg.sender);
    }

    // --- Views / helpers ---
    function getQuestion(
        uint256 questionId
    ) external view returns (Question memory) {
        return questions[questionId];
    }

    function getAnswer(
        uint256 questionId,
        uint256 answerId
    ) external view returns (Answer memory) {
        return answers[questionId][answerId];
    }
}
