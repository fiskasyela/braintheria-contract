// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {QnAStorage} from "./QnAStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract QnAAsk is QnAStorage {
    using SafeERC20 for IERC20;

    // ==================== EVENTS ====================

    event QuestionAsked(
        uint256 indexed questionId,
        address indexed asker,
        address indexed token,
        uint256 bounty,
        uint40 deadline,
        string uri
    );
    event BountyAdded(
        uint256 indexed questionId,
        uint256 amount,
        address token
    );
    event BountyRefunded(
        uint256 indexed questionId,
        address indexed to,
        uint256 amount,
        address token
    );
    event BountyReduced(
        uint256 indexed questionId,
        address indexed asker,
        uint256 oldBounty,
        uint256 newBounty,
        uint256 refund
    );
    event QuestionCancelled(uint256 indexed questionId, address indexed by);

    // ==================== MODIFIERS ====================

    modifier onlyAsker(uint256 questionId) {
        require(msg.sender == questions[questionId].asker, "Not asker");
        _;
    }

    // ==================== INTERNAL FUNCTIONS ====================

    /**
     * @notice Internal function to create a new question
     * @param token Token address (address(0) for native ETH)
     * @param bounty Bounty amount in wei
     * @param deadline Unix timestamp when question expires
     * @param uri IPFS or metadata URI for question content
     */
    function _askQuestion(
        address token,
        uint256 bounty,
        uint40 deadline,
        string calldata uri
    ) internal returns (uint256 questionId) {
        require(
            deadline >= block.timestamp + MIN_DEADLINE_DELAY,
            "Deadline too soon"
        );
        questionId = ++questionCounter;

        // Handle payment
        if (token == address(0)) {
            // Native ETH bounty
            require(msg.value == bounty, "Bad msg.value");
        } else {
            // ERC20 token bounty
            require(msg.value == 0, "No native with ERC20");
            if (bounty > 0) {
                IERC20(token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    bounty
                );
            }
        }

        // Store question data
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
            deadline,
            uri
        );
    }

    /**
     * @notice Internal function to add bounty to existing question
     * @param questionId ID of the question
     * @param amount Additional bounty amount
     */
    function _addBounty(uint256 questionId, uint256 amount) internal {
        require(amount > 0, "No amount");
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        address token = q.token;

        // Handle payment
        if (token == address(0)) {
            require(msg.value == amount, "Bad msg.value");
        } else {
            require(msg.value == 0, "No native with ERC20");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        q.bounty += amount;
        emit BountyAdded(questionId, amount, token);
    }

    function _reduceBounty(uint256 questionId, uint256 newAmount) internal {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Question not open");
        require(newAmount < q.bounty, "New bounty must be lower");

        uint256 refund = q.bounty - newAmount;
        address token = q.token;

        if (token == address(0)) {
            // refund in native ETH
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            require(success, "Refund failed");
        } else {
            // refund in ERC20 token
            IERC20(token).safeTransfer(msg.sender, refund);
        }

        uint256 oldBounty = q.bounty;
        q.bounty = newAmount;

        emit BountyReduced(
            questionId,
            msg.sender,
            oldBounty,
            newAmount,
            refund
        );
    }

    /**
     * @notice Internal function to refund bounty after deadline expires
     * @param questionId ID of the question
     */
    function _refundExpired(uint256 questionId) internal {
        Question storage q = questions[questionId];
        require(q.status == QuestionStatus.Open, "Not open");
        require(block.timestamp >= q.deadline, "Not expired");
        require(!q.refunded, "Already refunded");

        q.status = QuestionStatus.Expired;
        q.refunded = true;

        uint256 amount = q.bounty;
        q.bounty = 0;
        address token = q.token;

        // Refund the bounty
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
     * @notice Internal function to cancel question before any accepted answer
     * @param questionId ID of the question
     */
    function _cancelQuestion(uint256 questionId) internal {
        Question storage q = questions[questionId];

        require(q.status == QuestionStatus.Open, "Not open");
        require(q.acceptedAnswerId == 0, "Already accepted");

        q.status = QuestionStatus.Cancelled;

        uint256 amount = q.bounty;
        q.bounty = 0;
        address token = q.token;

        // Refund the bounty
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
}
