// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {QnAAsk} from "./QnAAsk.sol";
import {QnAAnswer} from "./QnAAnswer.sol";
import {QnAAdmin} from "./QnAAdmin.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract QnAWithBounty is QnAAsk, QnAAnswer, QnAAdmin, ReentrancyGuard {
    //Add event here (so backend can catch it)
    event QuestionAsked(
        uint256 indexed questionId,
        address indexed asker,
        uint256 bounty,
        string uri
    );

    constructor(address _owner) QnAAdmin(_owner) {}

    /**
     * @notice Ask a new question with optional ETH bounty
     */
    function askQuestion(
        address token,
        uint256 bounty,
        uint40 deadline,
        string calldata uri
    ) external payable whenNotPaused nonReentrant returns (uint256) {
        // Call internal logic from QnAAsk
        uint256 questionId = _askQuestion(token, bounty, deadline, uri);

        //Emit event so backend can parse it
        emit QuestionAsked(questionId, msg.sender, bounty, uri);

        return questionId;
    }

    function answerQuestion(
        uint256 questionId,
        string calldata uri
    ) external whenNotPaused {
        _postAnswer(questionId, uri);
    }

    /**
     * @notice Accept answer - only the question asker can call this
     * @dev This is for users who want to accept answers directly from their wallet
     */
    function acceptAnswer(
        uint256 questionId,
        uint256 answerId
    ) external onlyAsker(questionId) nonReentrant {
        _acceptAnswer(questionId, answerId);
    }

    /**
     * @notice Accept answer as admin - only contract owner (backend) can call this
     * @dev This allows your backend to accept answers on behalf of users
     * Add this function to fix the "Not asker" error
     */
    function acceptAnswerAsAdmin(
        uint256 questionId,
        uint256 answerId
    ) external onlyOwner nonReentrant {
        _acceptAnswer(questionId, answerId);
    }

    function addBounty(
        uint256 questionId,
        uint256 amount
    ) external payable nonReentrant {
        _addBounty(questionId, amount);
    }

    // 🔹 Added: externals to match your tests
    function refundExpired(
        uint256 questionId
    ) external onlyAsker(questionId) nonReentrant {
        _refundExpired(questionId);
    }

    function cancelQuestion(
        uint256 questionId
    ) external onlyAsker(questionId) nonReentrant {
        _cancelQuestion(questionId);
    }

    // views
    function getQuestion(uint256 id) external view returns (Question memory) {
        return questions[id];
    }

    function getAnswer(
        uint256 qid,
        uint256 aid
    ) external view returns (Answer memory) {
        return answers[qid][aid];
    }
}